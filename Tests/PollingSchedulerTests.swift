import Foundation
import Testing

@MainActor
struct PollingSchedulerTests {
    private func startedStore() async throws -> TestStore {
        var routes = TestStore.running
        routes["time-clock/status"] = Array(repeating: .fixture(200, "status-running"), count: 40)
        routes["time-tracking/work-summary"] = Array(repeating: .fixture(200, "work-summary"), count: 40)
        let harness = try TestStore(credentials: .apiToken("tb_secret"), routes: routes)
        await harness.store.start()
        return harness
    }

    @Test func tickRefreshesUnlessASkipWasRequested() async throws {
        let harness = try await startedStore()
        defer { harness.store.stopObserving() }
        let scheduler = PollingScheduler(store: harness.store)
        let afterStart = await harness.transport.requestCount(pathSuffix: "time-clock/status")
        harness.store.pollingSkipRequested = true
        await scheduler.tick()
        #expect(await harness.transport.requestCount(pathSuffix: "time-clock/status") == afterStart)
        #expect(!harness.store.pollingSkipRequested)
        await scheduler.tick()
        #expect(await harness.transport.requestCount(pathSuffix: "time-clock/status") == afterStart + 1)
    }

    /// Waits for a condition instead of a fixed window: on a shared CI runner every main-actor
    /// test competes for the main actor, and a 200 ms window saw fewer than three polls.
    private func waitUntil(timeout: Duration = .seconds(10), _ condition: () async -> Bool) async throws {
        let deadline = ContinuousClock.now + timeout
        while await !condition() {
            guard ContinuousClock.now < deadline else {
                Issue.record("Condition not met within \(timeout)")
                return
            }
            try await Task.sleep(for: .milliseconds(10))
        }
    }

    @Test func loopPollsRepeatedlyUntilStopped() async throws {
        let harness = try await startedStore()
        defer { harness.store.stopObserving() }
        let scheduler = PollingScheduler(store: harness.store, interval: .milliseconds(20))
        let statusRequests = { await harness.transport.requestCount(pathSuffix: "time-clock/status") }
        let afterStart = await statusRequests()
        scheduler.start()
        try await waitUntil { await statusRequests() >= afterStart + 3 }
        scheduler.stop()
        let atStop = await statusRequests()
        // A tick that was already past its sleep may still finish its refresh, nothing after it.
        // A loop that kept running would add about 25 polls in this time.
        try await Task.sleep(for: .milliseconds(500))
        let afterStop = await statusRequests()
        #expect(afterStop - atStop <= 1)
        try await Task.sleep(for: .milliseconds(200))
        #expect(await statusRequests() == afterStop)
    }

    @Test func tickWaitsWhileAClockActionRuns() async throws {
        let harness = try await startedStore()
        defer { harness.store.stopObserving() }
        let scheduler = PollingScheduler(store: harness.store)
        let afterStart = await harness.transport.requestCount(pathSuffix: "time-clock/status")
        harness.store.isBusy = true
        await scheduler.tick()
        #expect(await harness.transport.requestCount(pathSuffix: "time-clock/status") == afterStart)
        harness.store.isBusy = false
    }

    @Test func wakeRefreshesImmediately() async throws {
        let harness = try await startedStore()
        defer { harness.store.stopObserving() }
        let scheduler = PollingScheduler(store: harness.store)
        let afterStart = await harness.transport.requestCount(pathSuffix: "time-clock/status")
        await scheduler.wake()
        #expect(await harness.transport.requestCount(pathSuffix: "time-clock/status") == afterStart + 1)
    }
}
