import Foundation
import Testing

@MainActor
struct ClockStoreActionTests {
    private let laterSummary = Data(#"{"commitmentMinutes":480,"workedMinutes":200,"remainingMinutes":280,"percentDone":42,"breakMinutes":30}"#.utf8)

    private func startedStore(status: String = "status-running", routes extra: [String: [FixtureTransport.Reply]] = [:]) async throws -> TestStore {
        var routes = TestStore.running
        routes["time-clock/status"] = [.fixture(200, status)]
        for (path, replies) in extra {
            routes[path, default: []].append(contentsOf: replies)
        }
        let harness = try TestStore(credentials: .apiToken("tb_secret"), routes: routes)
        await harness.store.start()
        return harness
    }

    @Test func startAdoptsTheAnswerAndReloadsTheSummary() async throws {
        let harness = try await startedStore(status: "status-idle", routes: ["time-clock/start": [.fixture(200, "status-running")], "time-tracking/work-summary": [.raw(200, laterSummary)]])
        defer { harness.store.stopObserving() }
        await harness.store.perform(.start)
        #expect(harness.store.status?.status == .running)
        #expect(harness.store.summary?.workedMinutes == 200)
        #expect(harness.store.lastError == nil)
        #expect(!harness.store.isBusy)
        #expect(await harness.transport.requestCount(pathSuffix: "time-clock/start") == 1)
    }

    @Test func pauseResumeAndCancelPostToTheirPaths() async throws {
        let harness = try await startedStore(routes: [
            "time-clock/pause": [.fixture(200, "status-paused")],
            "time-clock/resume": [.fixture(200, "status-running")],
            "time-clock/cancel": [.fixture(200, "status-idle")],
            "time-tracking/work-summary": [.fixture(200, "work-summary"), .fixture(200, "work-summary"), .fixture(200, "work-summary")],
        ])
        defer { harness.store.stopObserving() }
        await harness.store.perform(.pause)
        #expect(harness.store.status?.status == .paused)
        await harness.store.perform(.resume)
        #expect(harness.store.status?.status == .running)
        await harness.store.perform(.cancel)
        #expect(harness.store.status?.status == .idle)
        let posts = await harness.transport.requests.filter { $0.method == "POST" }.map { $0.url.path() }
        #expect(posts == ["/api/v2/time-clock/pause", "/api/v2/time-clock/resume", "/api/v2/time-clock/cancel"])
    }

    @Test func savedStopShowsMessageAndRefreshes() async throws {
        let harness = try await startedStore(routes: ["time-clock/stop": [.fixture(200, "stop-saved")], "time-clock/status": [.fixture(200, "status-idle")], "time-tracking/work-summary": [.raw(200, laterSummary)]])
        defer { harness.store.stopObserving() }
        await harness.store.stop()
        #expect(harness.store.lastMessage == "Gespeichert: 7:30 (Pause 0:30), korrigiert")
        #expect(harness.store.status?.status == .idle)
        #expect(harness.store.summary?.workedMinutes == 200)
        #expect(harness.store.pendingBreakRegulation == nil)
        let stops = await harness.transport.requests.filter { $0.url.path().hasSuffix("time-clock/stop") }
        #expect(stops.map(\.bodyText) == [#"{"categoryId":0,"projectId":0}"#])
    }

    @Test func confirmationThenApplySavesWithDecision() async throws {
        let harness = try await startedStore(routes: [
            "time-clock/stop": [.fixture(200, "stop-confirmation"), .fixture(200, "stop-saved")],
            "time-clock/status": [.fixture(200, "status-running"), .fixture(200, "status-idle")],
            "time-tracking/work-summary": [.fixture(200, "work-summary"), .fixture(200, "work-summary")],
        ])
        defer { harness.store.stopObserving() }
        await harness.store.stop()
        #expect(harness.store.pendingBreakRegulation?.resultingWorkMinutes == 420)
        #expect(harness.store.lastMessage == nil)
        await harness.store.stop(decision: .apply)
        #expect(harness.store.pendingBreakRegulation == nil)
        #expect(harness.store.lastMessage == "Gespeichert: 7:30 (Pause 0:30), korrigiert")
        let stops = await harness.transport.requests.filter { $0.url.path().hasSuffix("time-clock/stop") }
        #expect(stops.map(\.bodyText) == [#"{"categoryId":0,"projectId":0}"#, #"{"breakRegulation":"apply","categoryId":0,"projectId":0}"#])
    }

    @Test func dismissingTheCardSendsNothing() async throws {
        let harness = try await startedStore(routes: ["time-clock/stop": [.fixture(200, "stop-confirmation")], "time-clock/status": [.fixture(200, "status-running")], "time-tracking/work-summary": [.fixture(200, "work-summary")]])
        defer { harness.store.stopObserving() }
        await harness.store.stop()
        let before = await harness.transport.requests.count
        harness.store.dismissBreakRegulation()
        #expect(harness.store.pendingBreakRegulation == nil)
        #expect(await harness.transport.requests.count == before)
    }

    @Test func stopWhileWaitingIsDiscarded() async throws {
        let harness = try await startedStore(status: "status-waiting", routes: ["time-clock/stop": [.raw(204, Data())], "time-clock/status": [.fixture(200, "status-idle")], "time-tracking/work-summary": [.fixture(200, "work-summary")]])
        defer { harness.store.stopObserving() }
        await harness.store.stop()
        #expect(harness.store.lastMessage == "Aufzeichnung verworfen.")
        #expect(harness.store.status?.status == .idle)
    }

    @Test func conflictShowsMessageAndReloadsStatus() async throws {
        let harness = try await startedStore(status: "status-idle", routes: ["time-clock/start": [.raw(409, Data("already running".utf8))], "time-clock/status": [.fixture(200, "status-running")]])
        defer { harness.store.stopObserving() }
        await harness.store.perform(.start)
        #expect(harness.store.lastError == "Stempeluhr läuft schon.")
        #expect(harness.store.status?.status == .running)
        #expect(await harness.transport.requestCount(pathSuffix: "time-clock/status") == 2)
    }

    @Test func actionErrorAfterSignOutIsIgnored() async throws {
        let harness = try await startedStore(routes: ["time-clock/pause": [.raw(401, Data())]])
        defer { harness.store.stopObserving() }
        await harness.transport.holdNextReply()
        let pause = Task { await harness.store.perform(.pause) }
        await harness.transport.waitForRequests(count: 4)
        await harness.store.signOut()
        await harness.transport.releaseHeldReply()
        await pause.value
        #expect(harness.store.session == .notConfigured)
        #expect(await harness.sessionManager.currentState() == .notConfigured)
        #expect(harness.store.lastError == nil)
    }

    @Test func unauthorizedActionExpiresTheSession() async throws {
        let harness = try await startedStore(routes: ["time-clock/pause": [.raw(401, Data())]])
        defer { harness.store.stopObserving() }
        await harness.store.perform(.pause)
        #expect(harness.store.session == .expired)
        #expect(harness.store.status == nil)
    }

    @Test func secondClickWhileBusyIsIgnored() async throws {
        let harness = try await startedStore(routes: ["time-clock/pause": [.fixture(200, "status-paused")], "time-tracking/work-summary": [.fixture(200, "work-summary")]])
        defer { harness.store.stopObserving() }
        await harness.transport.holdNextReply()
        let first = Task { await harness.store.perform(.pause) }
        await harness.transport.waitForRequests(count: 4)
        #expect(harness.store.isBusy)
        await harness.store.perform(.pause)
        await harness.transport.releaseHeldReply()
        await first.value
        #expect(await harness.transport.requestCount(pathSuffix: "time-clock/pause") == 1)
        #expect(harness.store.status?.status == .paused)
        #expect(!harness.store.isBusy)
    }

    @Test(arguments: [
        (SavedTimeEntry(id: "1", workedMinutes: 450, breakMinutes: 30, breakRegulationApplied: true, breakRegulationIgnored: false), "Gespeichert: 7:30 (Pause 0:30), korrigiert"),
        (SavedTimeEntry(id: "2", workedMinutes: 60, breakMinutes: 0, breakRegulationApplied: false, breakRegulationIgnored: false), "Gespeichert: 1:00"),
        (SavedTimeEntry(id: "3", workedMinutes: 605, breakMinutes: 45, breakRegulationApplied: false, breakRegulationIgnored: true), "Gespeichert: 10:05 (Pause 0:45)"),
    ])
    func savedMessageFollowsTheFormat(entry: SavedTimeEntry, expected: String) {
        #expect(ClockStore.savedMessage(for: entry) == expected)
    }
}
