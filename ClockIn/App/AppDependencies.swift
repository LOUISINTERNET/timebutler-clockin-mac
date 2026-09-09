import Foundation

/// Composition root: the one place that knows the concrete transport and stores.
@MainActor
struct AppDependencies {
    let store: ClockStore
    let scheduler: PollingScheduler
    let preferences: Preferences

    init() throws {
        let transport = URLSessionTransport()
        let sessionManager = try SessionManager(credentialStore: KeychainCredentialStore(), oauthClient: OAuthClient(transport: transport))
        let api = TimebutlerAPI(transport: transport, tokenProvider: sessionManager)
        store = ClockStore(api: api, sessionManager: sessionManager)
        scheduler = PollingScheduler(store: store)
        preferences = Preferences()
    }
}
