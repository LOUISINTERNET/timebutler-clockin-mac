import Foundation
import Testing

@MainActor
struct ClockStoreReconnectTests {
    private static let offlineMessage = "Keine Verbindung zu Timebutler."

    /// The status call fails `statusFailures` times without a connection, then answers `running`.
    private func harness(statusFailures: Int, retryDelays: [Duration]) throws -> TestStore {
        let status = Array(repeating: TestStore.offline, count: statusFailures) + Array(repeating: .fixture(200, "status-running"), count: 5)
        return try TestStore(credentials: .apiToken("tb_secret"), routes: TestStore.routes(status: status), connectionRetryDelays: retryDelays)
    }

    @Test func refreshWithoutConnectionRetriesUntilTheStatusArrives() async throws {
        let harness = try harness(statusFailures: 2, retryDelays: [.milliseconds(10), .milliseconds(10), .milliseconds(10)])
        let store = harness.store
        await store.start()
        defer { store.stopObserving() }
        // No check of the first error here: `start()` still awaits the parallel calls and the
        // profile after `handle`, and a 10 ms retry can finish within that on a slow runner.
        try await waitUntil { store.status != nil }
        #expect(store.status?.status == .running)
        #expect(store.lastError == nil)
        #expect(await harness.statusRequestCount() == 3)
        #expect(!store.isConnectionRetryPending)
    }

    @Test func retriesEndAfterTheLastDelay() async throws {
        let harness = try harness(statusFailures: 10, retryDelays: [.milliseconds(10), .milliseconds(10)])
        let store = harness.store
        await store.start()
        defer { store.stopObserving() }
        try await waitUntil { await harness.statusRequestCount() >= 3 }
        // A further retry would have fired within 10 ms.
        try await Task.sleep(for: .milliseconds(200))
        #expect(await harness.statusRequestCount() == 3)
        #expect(!store.isConnectionRetryPending)
        #expect(store.lastError == Self.offlineMessage)
    }

    @Test func successfulRefreshCancelsThePendingRetry() async throws {
        let harness = try harness(statusFailures: 1, retryDelays: [.seconds(3600)])
        let store = harness.store
        await store.start()
        defer { store.stopObserving() }
        #expect(store.isConnectionRetryPending)
        await store.refresh()
        #expect(store.status?.status == .running)
        #expect(!store.isConnectionRetryPending)
    }

    @Test func retriesStartOverAfterASuccess() async throws {
        let routes = TestStore.routes(status: [TestStore.offline, .fixture(200, "status-running"), TestStore.offline, .fixture(200, "status-paused")])
        let harness = try TestStore(credentials: .apiToken("tb_secret"), routes: routes, connectionRetryDelays: [.milliseconds(10)])
        let store = harness.store
        await store.start()
        defer { store.stopObserving() }
        try await waitUntil { store.status?.status == .running }
        // Fails again; only a counter that started over plans another retry.
        await store.refresh()
        try await waitUntil { store.status?.status == .paused }
        #expect(store.lastError == nil)
        #expect(await harness.statusRequestCount() == 4)
    }

    @Test func signOutCancelsThePendingRetry() async throws {
        let harness = try harness(statusFailures: 1, retryDelays: [.seconds(3600)])
        let store = harness.store
        await store.start()
        defer { store.stopObserving() }
        #expect(store.isConnectionRetryPending)
        await store.signOut()
        #expect(store.session == .notConfigured)
        #expect(!store.isConnectionRetryPending)
    }

    /// The action's own error stays visible (FR-C10); a retry's refresh would clear it.
    @Test func failedActionWithoutConnectionSchedulesNoRetry() async throws {
        let harness = try harness(statusFailures: 0, retryDelays: [.milliseconds(10)])
        let store = harness.store
        await store.start()
        defer { store.stopObserving() }
        await harness.transport.route("time-clock/pause", [TestStore.offline])
        await store.perform(.pause)
        #expect(store.lastError == Self.offlineMessage)
        #expect(!store.isConnectionRetryPending)
    }

    /// EC-6: a launch without connection misses the profile too; the first trigger that
    /// brings a status back loads it, a trigger that fails again does not try.
    @Test func statusAfterAnOfflineLaunchAlsoLoadsTheMissingProfile() async throws {
        var routes = TestStore.routes(status: [TestStore.offline, TestStore.offline, .fixture(200, "status-running")])
        routes["user/profile"] = [TestStore.offline, .fixture(200, "profile")]
        let harness = try TestStore(credentials: .apiToken("tb_secret"), routes: routes, connectionRetryDelays: [.seconds(3600)])
        let store = harness.store
        await store.start()
        defer { store.stopObserving() }
        #expect(store.profile == nil)
        await store.refreshUnlessBusy(after: "Network is back")
        #expect(store.profile == nil)
        #expect(await harness.transport.requestCount(pathSuffix: "user/profile") == 1)
        await store.refreshUnlessBusy(after: "Network is back")
        #expect(store.profile?.name == "Maria Müller")
        #expect(await harness.transport.requestCount(pathSuffix: "user/profile") == 2)
    }

    @Test func retryWaitsWhileAClockActionRuns() async throws {
        let harness = try harness(statusFailures: 1, retryDelays: [.milliseconds(10)])
        let store = harness.store
        // Busy before the start, so the 10 ms retry cannot fire before the flag is set.
        store.isBusy = true
        await store.start()
        defer { store.stopObserving() }
        #expect(store.connectionRetryAttempt == 1)
        try await waitUntil { !store.isConnectionRetryPending }
        #expect(await harness.statusRequestCount() == 1)
    }
}
