import Foundation

/// Builds a `SessionManager` on in-memory fakes with a frozen clock.
enum SessionManagerHarness {
    static let now = Date(timeIntervalSince1970: 1_800_000_000)
    static let freshAccessToken = "eyJhbGciOiJSUzI1NiJ9.fixture-access-token"

    static func makeManager(store: InMemoryCredentialStore, replies: [FixtureTransport.Reply]) throws -> (SessionManager, FixtureTransport) {
        let transport = FixtureTransport(replies)
        let client = OAuthClient(transport: transport, now: { now })
        return (try SessionManager(credentialStore: store, oauthClient: client, now: { now }), transport)
    }

    /// An OAuth session whose access token expires in ten seconds, inside the refresh lead time.
    static func staleSession(email: String = "user@example.com") -> OAuthSession {
        OAuthSession(accessToken: "old-access", refreshToken: "rt-old", expiresAt: now.addingTimeInterval(10), email: email)
    }
}
