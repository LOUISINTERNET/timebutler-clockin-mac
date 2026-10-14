import Foundation

/// A `ClockStore` wired with in-memory fakes, plus handles to those fakes.
@MainActor
struct TestStore {
    nonisolated static let now = Date(timeIntervalSince1970: 1_800_000_000)

    /// Replies for a running clock: status, work summary and profile, one each.
    nonisolated static let running: [String: [FixtureTransport.Reply]] = [
        "time-clock/status": [.fixture(200, "status-running")],
        "time-tracking/work-summary": [.fixture(200, "work-summary")],
        "user/profile": [.fixture(200, "profile")],
        "time-entries/my": [.fixture(200, "time-entries")],
    ]

    nonisolated static let offline = FixtureTransport.Reply.failure(TransportError(description: "-1009 offline"))

    /// `running` with the given status replies in order. Every refresh also calls work summary
    /// and time entries in parallel, so both answer once per status reply.
    nonisolated static func routes(status: [FixtureTransport.Reply]) -> [String: [FixtureTransport.Reply]] {
        var routes = running
        routes["time-clock/status"] = status
        routes["time-tracking/work-summary"] = Array(repeating: .fixture(200, "work-summary"), count: status.count)
        routes["time-entries/my"] = Array(repeating: .fixture(200, "time-entries"), count: status.count)
        return routes
    }

    let store: ClockStore
    let transport: FixtureTransport
    let credentialStore: InMemoryCredentialStore
    let sessionManager: SessionManager

    init(
        credentials: Credentials?,
        routes: [String: [FixtureTransport.Reply]] = [:],
        connectionRetryDelays: [Duration] = ClockStore.defaultConnectionRetryDelays
    ) throws {
        credentialStore = InMemoryCredentialStore(credentials)
        transport = FixtureTransport(routes: routes)
        let oauthClient = OAuthClient(transport: transport, now: { Self.now })
        sessionManager = try SessionManager(credentialStore: credentialStore, oauthClient: oauthClient, now: { Self.now })
        let api = TimebutlerAPI(transport: transport, tokenProvider: sessionManager)
        store = ClockStore(api: api, sessionManager: sessionManager, connectionRetryDelays: connectionRetryDelays, now: { Self.now })
    }

    func statusRequestCount() async -> Int {
        await transport.requestCount(pathSuffix: "time-clock/status")
    }

    nonisolated static func staleOAuthSession(email: String = "user@example.com") -> OAuthSession {
        OAuthSession(accessToken: "old-access", refreshToken: "rt-old", expiresAt: now.addingTimeInterval(10), email: email)
    }
}
