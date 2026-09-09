import AppKit
import Foundation

/// Refreshes the store every minute and right after the Mac wakes up (FR-C1, EC-2).
/// One planned poll is skipped after a 429 (FR-C12).
@MainActor
final class PollingScheduler {
    private let store: ClockStore
    private let interval: Duration
    private let logger = Log.logger(.clock)
    private var loop: Task<Void, Never>?
    private var wakeObserver: (any NSObjectProtocol)?

    init(store: ClockStore, interval: Duration = .seconds(60)) {
        self.store = store
        self.interval = interval
    }

    func start() {
        stop()
        let interval = interval
        loop = Task { [weak self] in
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: interval)
                } catch {
                    return
                }
                guard let self else {
                    return
                }
                await self.tick()
            }
        }
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                await self?.wake()
            }
        }
        logger.notice("Polling every \(String(describing: interval), privacy: .public)")
    }

    func stop() {
        loop?.cancel()
        loop = nil
        if let wakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver)
            self.wakeObserver = nil
        }
    }

    /// One planned poll. Honours the skip the store requests after a 429 and does nothing
    /// when `stop()` cancelled the loop while this tick was already on its way.
    func tick() async {
        guard !Task.isCancelled else {
            return
        }
        if store.isBusy {
            logger.notice("Skipping a poll while a clock action is running")
            return
        }
        if store.pollingSkipRequested {
            store.pollingSkipRequested = false
            logger.notice("Skipping one poll after a rate limit")
            return
        }
        await store.refresh()
    }

    func wake() async {
        logger.notice("Mac woke up, refreshing")
        await store.refresh()
    }
}
