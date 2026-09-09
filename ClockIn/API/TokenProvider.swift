/// Supplies the bearer token for API calls. The session manager implements it for stored
/// credentials; a static provider is used while verifying a freshly entered API token.
protocol TokenProvider: Sendable {
    func accessToken() async throws -> String

    /// Called once after a 401. Returns a fresh token to retry with, or nil when the
    /// credentials cannot be refreshed (personal API tokens).
    func recoverFromUnauthorized() async throws -> String?
}

struct StaticTokenProvider: TokenProvider {
    let token: String

    func accessToken() async throws -> String {
        token
    }

    func recoverFromUnauthorized() async throws -> String? {
        nil
    }
}
