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
    ]

    let store: ClockStore
    let transport: FixtureTransport
    let credentialStore: InMemoryCredentialStore
    let sessionManager: SessionManager

    init(credentials: Credentials?, routes: [String: [FixtureTransport.Reply]] = [:]) throws {
        credentialStore = InMemoryCredentialStore(credentials)
        transport = FixtureTransport(routes: routes)
        let oauthClient = OAuthClient(transport: transport, now: { Self.now })
        sessionManager = try SessionManager(credentialStore: credentialStore, oauthClient: oauthClient, now: { Self.now })
        let api = TimebutlerAPI(transport: transport, tokenProvider: sessionManager)
        store = ClockStore(api: api, sessionManager: sessionManager, now: { Self.now })
    }

    nonisolated static func staleOAuthSession(email: String = "user@example.com") -> OAuthSession {
        OAuthSession(accessToken: "old-access", refreshToken: "rt-old", expiresAt: now.addingTimeInterval(10), email: email)
    }
}
