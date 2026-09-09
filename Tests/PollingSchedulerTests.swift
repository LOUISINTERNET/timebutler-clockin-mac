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

    @Test func loopPollsRepeatedlyUntilStopped() async throws {
        let harness = try await startedStore()
        defer { harness.store.stopObserving() }
        let scheduler = PollingScheduler(store: harness.store, interval: .milliseconds(20))
        let afterStart = await harness.transport.requestCount(pathSuffix: "time-clock/status")
        scheduler.start()
        try await Task.sleep(for: .milliseconds(200))
        scheduler.stop()
        // A tick that was already past its sleep may still finish; give it time before counting.
        try await Task.sleep(for: .milliseconds(100))
        let afterStop = await harness.transport.requestCount(pathSuffix: "time-clock/status")
        #expect(afterStop - afterStart >= 3)
        try await Task.sleep(for: .milliseconds(100))
        #expect(await harness.transport.requestCount(pathSuffix: "time-clock/status") == afterStop)
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
