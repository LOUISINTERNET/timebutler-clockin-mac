import Foundation
import Observation

/// A password sign-in that is waiting for the six-digit authenticator code (FR-S3).
struct PendingMFA: Sendable, Equatable {
    let token: String
    let email: String
}

/// Single source of truth for every view (design decision D5) and the only place that
/// catches errors from the API and the session (D10). Views read it; only the store and
/// its extensions write to it.
@MainActor
@Observable
final class ClockStore {
    var session: SessionState = .notConfigured
    var status: TimeClockStatus?
    var summary: WorkSummary?
    /// "08:37": the day's first clock-in from the saved entries, nil without one (FR-C2).
    var firstStartToday: String?
    var fetchedAt: Date?
    var profile: UserProfile?
    var pendingBreakRegulation: BreakRegulation?
    var pendingMFA: PendingMFA?
    var lastError: String?
    var lastMessage: String?
    var authError: String?
    /// A clock action is running; the widget disables its buttons (FR-C7, EC-9).
    var isBusy = false
    /// A sign-in or sign-out is running; the account tab disables its form.
    var isAuthenticating = false
    /// Set after a 429 so the scheduler skips its next planned poll (FR-C12).
    var pollingSkipRequested = false

    let api: TimebutlerAPI
    let sessionManager: SessionManager
    let now: @Sendable () -> Date
    let logger = Log.logger(.clock)
    /// The waits before each retry after a refresh that found no connection (FR-C14).
    let connectionRetryDelays: [Duration]
    var connectionRetry: Task<Void, Never>?
    var connectionRetryAttempt = 0
    private var stateObservation: Task<Void, Never>?
    private var applyingState: SessionState?
    private var applyTask: Task<Void, Never>?
    /// Bumped on every write of `status` or `summary`; a fetch only writes if nothing newer
    /// arrived meanwhile.
    private var fetchVersion = 0

    init(
        api: TimebutlerAPI,
        sessionManager: SessionManager,
        connectionRetryDelays: [Duration] = ClockStore.defaultConnectionRetryDelays,
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.api = api
        self.sessionManager = sessionManager
        self.connectionRetryDelays = connectionRetryDelays
        self.now = now
    }

    /// Adopts the stored session and keeps following the session manager's state changes.
    /// The subscription is opened first so nothing published during the first sync is lost.
    func start() async {
        stopObserving()
        let states = await sessionManager.states()
        await synchronizeSession()
        stateObservation = Task { [weak self] in
            for await state in states {
                guard let self else {
                    return
                }
                await self.apply(state)
            }
        }
    }

    /// Ends the session observation. Not called `stop()`: that name belongs to the clock.
    func stopObserving() {
        stateObservation?.cancel()
        stateObservation = nil
    }

    /// Loads status and work summary in parallel (FR-C1). A failing summary keeps the
    /// previous one and only logs (FR-C13); a failing status is reported via `lastError`.
    /// Results that arrive after the session changed are dropped. Returns whether this call
    /// adopted a status.
    @discardableResult
    func refresh() async -> Bool {
        let expected = session
        guard expected.isActive else {
            logger.info("Refresh skipped, no active session")
            return false
        }
        var version = fetchVersion
        async let statusCall = api.status()
        async let summaryCall = api.workSummary()
        async let entriesCall = api.timeEntries()
        do {
            let fetchedStatus = try await statusCall
            guard session == expected, fetchVersion == version else {
                logger.notice("Dropping a status answer that was overtaken by a newer one")
                return false
            }
            adopt(status: fetchedStatus)
            version = fetchVersion
            lastError = nil
        } catch {
            guard session == expected else {
                return false
            }
            await handle(error, during: nil)
            return false
        }
        do {
            let fetchedSummary = try await summaryCall
            guard session == expected, fetchVersion == version else {
                return true
            }
            adopt(summary: fetchedSummary)
        } catch {
            logger.error("Work summary failed, keeping the previous one: \(String(describing: error), privacy: .private)")
        }
        do {
            let entries = try await entriesCall
            guard session == expected else {
                return true
            }
            firstStartToday = DayStart.firstStart(entries: entries, today: DayStart.dayString(for: now()))
        } catch {
            logger.error("Time entries failed, keeping the previous day start: \(String(describing: error), privacy: .private)")
        }
        return true
    }

    /// The write paths for fetched values; every fetch checks `fetchVersion` before calling them.
    /// A status that arrived proves the connection, so it also ends a waiting connection retry.
    func adopt(status fetched: TimeClockStatus) {
        status = fetched
        fetchedAt = now()
        fetchVersion += 1
        resetConnectionRetry()
        logger.notice("Status \(fetched.status.rawValue, privacy: .public): work \(fetched.workTimeElapsedSeconds, privacy: .public) s, break \(fetched.breakElapsedSeconds, privacy: .public) s, accumulated break \(fetched.accumulatedBreakSeconds, privacy: .public) s")
    }

    func adopt(summary fetched: WorkSummary) {
        summary = fetched
        fetchVersion += 1
    }

    var currentFetchVersion: Int {
        fetchVersion
    }

    /// Reads the manager's current state. Called after every own sign-in or sign-out so the
    /// result is visible before the method returns; the stream delivers the same state and
    /// joins the apply that is already running.
    func synchronizeSession() async {
        await apply(await sessionManager.currentState())
    }

    /// Applies a session state exactly once: a second call for the state that is being
    /// applied waits for that apply, a call for the current state is a no-op. The join must
    /// never be reached from inside `perform` for the same state, or it would wait on itself;
    /// `handle` only synchronizes after 401 and `SessionError.expired`, which yield another state.
    func apply(_ state: SessionState) async {
        if state == applyingState, let applyTask {
            await applyTask.value
            return
        }
        guard state != session else {
            return
        }
        applyingState = state
        let task = Task { await self.perform(state) }
        applyTask = task
        await task.value
        if applyTask == task {
            applyTask = nil
            applyingState = nil
        }
    }

    private func perform(_ state: SessionState) async {
        session = state
        resetConnectionRetry()
        logger.notice("Session is now \(String(describing: state), privacy: .private)")
        if state.isActive {
            authError = nil
            pendingMFA = nil
            await refresh()
            guard session == state else {
                return
            }
            if profile == nil {
                await loadProfile()
            }
        } else {
            status = nil
            summary = nil
            firstStartToday = nil
            fetchedAt = nil
            profile = nil
            pendingBreakRegulation = nil
            lastMessage = nil
            lastError = nil
        }
    }
}
