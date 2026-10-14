import Foundation
import Testing

@MainActor
struct PollingSchedulerTests {
    private func startedStore() async throws -> TestStore {
        let routes = TestStore.routes(status: Array(repeating: .fixture(200, "status-running"), count: 40))
        let harness = try TestStore(credentials: .apiToken("tb_secret"), routes: routes)
        await harness.store.start()
        return harness
    }

    private func scheduler(for harness: TestStore, paths: FakeNetworkPathSource = FakeNetworkPathSource(), interval: Duration = .seconds(60)) -> PollingScheduler {
        PollingScheduler(store: harness.store, networkPaths: paths, interval: interval)
    }

    @Test func tickRefreshesUnlessASkipWasRequested() async throws {
        let harness = try await startedStore()
        defer { harness.store.stopObserving() }
        let scheduler = scheduler(for: harness)
        let afterStart = await harness.statusRequestCount()
        harness.store.pollingSkipRequested = true
        await scheduler.tick()
        #expect(await harness.statusRequestCount() == afterStart)
        #expect(!harness.store.pollingSkipRequested)
        await scheduler.tick()
        #expect(await harness.statusRequestCount() == afterStart + 1)
    }

    @Test func loopPollsRepeatedlyUntilStopped() async throws {
        let harness = try await startedStore()
        defer { harness.store.stopObserving() }
        let scheduler = scheduler(for: harness, interval: .milliseconds(20))
        let afterStart = await harness.statusRequestCount()
        scheduler.start()
        try await waitUntil { await harness.statusRequestCount() >= afterStart + 3 }
        scheduler.stop()
        let atStop = await harness.statusRequestCount()
        // A tick that was already past its sleep may still finish its refresh, nothing after it.
        // A loop that kept running would add about 25 polls in this time.
        try await Task.sleep(for: .milliseconds(500))
        let afterStop = await harness.statusRequestCount()
        #expect(afterStop - atStop <= 1)
        try await Task.sleep(for: .milliseconds(200))
        #expect(await harness.statusRequestCount() == afterStop)
    }

    @Test func tickWaitsWhileAClockActionRuns() async throws {
        let harness = try await startedStore()
        defer { harness.store.stopObserving() }
        let scheduler = scheduler(for: harness)
        let afterStart = await harness.statusRequestCount()
        harness.store.isBusy = true
        await scheduler.tick()
        #expect(await harness.statusRequestCount() == afterStart)
    }

    @Test func wakeRefreshesImmediately() async throws {
        let harness = try await startedStore()
        defer { harness.store.stopObserving() }
        let scheduler = scheduler(for: harness)
        let afterStart = await harness.statusRequestCount()
        await scheduler.wake()
        #expect(await harness.statusRequestCount() == afterStart + 1)
    }

    @Test func networkReturnRefreshesButTheFirstPathAndChangesBetweenConnectionsDoNot() async throws {
        let harness = try await startedStore()
        defer { harness.store.stopObserving() }
        let scheduler = scheduler(for: harness)
        let afterStart = await harness.statusRequestCount()
        await scheduler.networkPathChanged(isSatisfied: true)
        await scheduler.networkPathChanged(isSatisfied: true)
        #expect(await harness.statusRequestCount() == afterStart)
        await scheduler.networkPathChanged(isSatisfied: false)
        #expect(await harness.statusRequestCount() == afterStart)
        await scheduler.networkPathChanged(isSatisfied: true)
        #expect(await harness.statusRequestCount() == afterStart + 1)
    }

    @Test func networkReturnWaitsWhileAClockActionRuns() async throws {
        let harness = try await startedStore()
        defer { harness.store.stopObserving() }
        let scheduler = scheduler(for: harness)
        let afterStart = await harness.statusRequestCount()
        harness.store.isBusy = true
        await scheduler.networkPathChanged(isSatisfied: false)
        await scheduler.networkPathChanged(isSatisfied: true)
        #expect(await harness.statusRequestCount() == afterStart)
    }

    /// Wi-Fi that joins after the short retries have stretched to a long wait: a refresh that
    /// still fails right after the return starts again with the first delay.
    @Test func networkReturnRestartsTheShortRetries() async throws {
        let routes = TestStore.routes(status: [TestStore.offline, TestStore.offline, TestStore.offline, .fixture(200, "status-running")])
        let harness = try TestStore(credentials: .apiToken("tb_secret"), routes: routes, connectionRetryDelays: [.milliseconds(10), .seconds(3600)])
        let store = harness.store
        await store.start()
        defer { store.stopObserving() }
        try await waitUntil { await harness.statusRequestCount() == 2 && store.isConnectionRetryPending }
        let scheduler = scheduler(for: harness)
        await scheduler.networkPathChanged(isSatisfied: false)
        await scheduler.networkPathChanged(isSatisfied: true)
        try await waitUntil { store.status != nil }
        #expect(store.status?.status == .running)
        #expect(await harness.statusRequestCount() == 4)
    }

    @Test func startFollowsThePathSourceUntilStopped() async throws {
        let harness = try await startedStore()
        defer { harness.store.stopObserving() }
        let paths = FakeNetworkPathSource()
        let scheduler = scheduler(for: harness, paths: paths, interval: .seconds(3600))
        let afterStart = await harness.statusRequestCount()
        scheduler.start()
        paths.continuation.yield(false)
        paths.continuation.yield(true)
        try await waitUntil { await harness.statusRequestCount() == afterStart + 1 }
        scheduler.stop()
        paths.continuation.yield(false)
        paths.continuation.yield(true)
        try await Task.sleep(for: .milliseconds(200))
        #expect(await harness.statusRequestCount() == afterStart + 1)
    }
}
