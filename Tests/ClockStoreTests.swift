import Foundation
import Testing

@MainActor
struct ClockStoreTests {
    @Test func startWithApiTokenLoadsStatusSummaryAndProfile() async throws {
        let harness = try TestStore(credentials: .apiToken("tb_secret"), routes: TestStore.running)
        let store = harness.store
        await store.start()
        defer { store.stopObserving() }
        #expect(store.session == .active(.apiToken))
        #expect(store.status?.status == .running)
        #expect(store.summary?.commitmentMinutes == 480)
        #expect(store.profile?.name == "Maria Müller")
        #expect(store.fetchedAt == TestStore.now)
        #expect(store.lastError == nil)
        #expect(await harness.transport.requests.count == 3)
    }

    @Test func noCredentialsMeansNoRequests() async throws {
        let harness = try TestStore(credentials: nil, routes: TestStore.running)
        await harness.store.start()
        defer { harness.store.stopObserving() }
        #expect(harness.store.session == .notConfigured)
        #expect(harness.store.status == nil)
        #expect(await harness.transport.requests.isEmpty)
    }

    @Test func unauthorizedWithApiTokenExpiresTheSession() async throws {
        let harness = try TestStore(credentials: .apiToken("tb_secret"), routes: TestStore.running)
        let store = harness.store
        await store.start()
        defer { store.stopObserving() }
        await harness.transport.route("time-clock/status", [.raw(401, Data())])
        await harness.transport.route("time-tracking/work-summary", [.fixture(200, "work-summary")])
        await store.refresh()
        #expect(store.session == .expired)
        #expect(store.status == nil)
        #expect(store.summary == nil)
        #expect(store.profile == nil)
        #expect(store.lastError == nil)
        #expect(await harness.sessionManager.currentState() == .expired)
    }

    @Test func rejectedRefreshTokenExpiresTheSessionBeforeAnyStatusCall() async throws {
        let harness = try TestStore(credentials: .oauth(TestStore.staleOAuthSession()), routes: ["oauth2/token": [.fixture(400, "oauth-error")]])
        let store = harness.store
        await store.start()
        defer { store.stopObserving() }
        #expect(store.session == .expired)
        #expect(store.status == nil)
        #expect(await harness.transport.requestCount(pathSuffix: "time-clock/status") == 0)
    }

    @Test func transportFailureKeepsTheLastStatus() async throws {
        let harness = try TestStore(credentials: .apiToken("tb_secret"), routes: TestStore.running)
        let store = harness.store
        await store.start()
        defer { store.stopObserving() }
        await harness.transport.route("time-clock/status", [.failure(TransportError(description: "offline"))])
        await harness.transport.route("time-tracking/work-summary", [.failure(TransportError(description: "offline"))])
        await store.refresh()
        #expect(store.lastError == "Keine Verbindung zu Timebutler.")
        #expect(store.status?.status == .running)
        #expect(store.summary?.commitmentMinutes == 480)
        #expect(store.session == .active(.apiToken))
    }

    @Test func summaryFailureKeepsStatusAndPreviousSummary() async throws {
        var routes = TestStore.running
        routes["time-tracking/work-summary"] = [.raw(200, Data(#"{"commitmentMinutes":420,"workedMinutes":100,"remainingMinutes":320,"percentDone":24,"breakMinutes":15}"#.utf8))]
        let harness = try TestStore(credentials: .apiToken("tb_secret"), routes: routes)
        let store = harness.store
        await store.start()
        defer { store.stopObserving() }
        #expect(store.summary?.workedMinutes == 100)
        await harness.transport.route("time-clock/status", [.fixture(200, "status-paused")])
        await harness.transport.route("time-tracking/work-summary", [.raw(500, Data())])
        await store.refresh()
        #expect(store.status?.status == .paused)
        #expect(store.summary?.workedMinutes == 100)
        #expect(store.lastError == nil)
    }

    @Test func staleStatusAnswerDoesNotOvertakeANewerOne() async throws {
        let harness = try TestStore(credentials: .apiToken("tb_secret"), routes: TestStore.running)
        let store = harness.store
        await store.start()
        defer { store.stopObserving() }
        await harness.transport.route("time-clock/status", [.fixture(200, "status-running")])
        await harness.transport.route("time-tracking/work-summary", [.fixture(200, "work-summary"), .fixture(200, "work-summary")])
        await harness.transport.route("time-clock/pause", [.fixture(200, "status-paused")])
        await harness.transport.holdNextReply()
        let poll = Task { await store.refresh() }
        await harness.transport.waitForRequests(count: 4)
        await store.perform(.pause)
        #expect(store.status?.status == .paused)
        await harness.transport.releaseHeldReply()
        await poll.value
        #expect(store.status?.status == .paused)
    }

    @Test func observationCanBeStoppedAndStartedAgain() async throws {
        let harness = try TestStore(credentials: .apiToken("tb_secret"), routes: TestStore.running)
        let store = harness.store
        await store.start()
        store.stopObserving()
        await store.start()
        defer { store.stopObserving() }
        await harness.sessionManager.markExpired()
        for _ in 0..<1000 where store.session != .expired {
            await Task.yield()
        }
        #expect(store.session == .expired)
    }

    @Test func rateLimitRequestsAPollingSkip() async throws {
        let harness = try TestStore(credentials: .apiToken("tb_secret"), routes: TestStore.running)
        let store = harness.store
        await store.start()
        defer { store.stopObserving() }
        await harness.transport.route("time-clock/status", [.raw(429, Data())])
        await harness.transport.route("time-tracking/work-summary", [.fixture(200, "work-summary")])
        await store.refresh()
        #expect(store.pollingSkipRequested)
        #expect(store.lastError == "Zu viele Anfragen. Kurz warten.")
        #expect(store.status?.status == .running)
    }

    @Test func expiryFromTheSessionManagerArrivesThroughTheStream() async throws {
        let harness = try TestStore(credentials: .apiToken("tb_secret"), routes: TestStore.running)
        let store = harness.store
        await store.start()
        defer { store.stopObserving() }
        await harness.sessionManager.markExpired()
        for _ in 0..<1000 where store.session != .expired {
            await Task.yield()
        }
        #expect(store.session == .expired)
        #expect(store.status == nil)
    }
}
