import Foundation
import Testing

@MainActor
struct ClockStoreSessionTests {
    private let email = "user@example.com"

    @Test func apiTokenSignInVerifiesStoresAndRefreshes() async throws {
        let harness = try TestStore(credentials: nil, routes: TestStore.running)
        let store = harness.store
        await store.start()
        defer { store.stopObserving() }
        #expect(await store.signIn(apiToken: "tb_new"))
        #expect(store.session == .active(.apiToken))
        #expect(store.profile?.name == "Maria Müller")
        #expect(store.status?.status == .running)
        #expect(store.authError == nil)
        #expect(!store.isAuthenticating)
        #expect(harness.credentialStore.stored == .apiToken("tb_new"))
        #expect(await harness.transport.requestCount(pathSuffix: "user/profile") == 1)
    }

    @Test func rejectedApiTokenKeepsSessionAndShowsMessage() async throws {
        let harness = try TestStore(credentials: nil, routes: ["user/profile": [.raw(401, Data())]])
        let store = harness.store
        await store.start()
        defer { store.stopObserving() }
        #expect(await store.signIn(apiToken: "tb_wrong") == false)
        #expect(store.authError == ClockStore.rejectedTokenMessage)
        #expect(store.session == .notConfigured)
        #expect(harness.credentialStore.stored == nil)
        #expect(!store.isAuthenticating)
    }

    @Test func forbiddenTokenCheckCountsAsRejected() async throws {
        let harness = try TestStore(credentials: nil, routes: ["user/profile": [.raw(403, Data())]])
        let store = harness.store
        await store.start()
        defer { store.stopObserving() }
        #expect(await store.signIn(apiToken: "tb_blocked") == false)
        #expect(store.authError == ClockStore.rejectedTokenMessage)
    }

    @Test func passwordSignInWithMfaCompletesAndRefreshes() async throws {
        var routes = TestStore.running
        routes["oauth2/token"] = [.fixture(200, "oauth-mfa"), .fixture(200, "oauth-token")]
        let harness = try TestStore(credentials: nil, routes: routes)
        let store = harness.store
        await store.start()
        defer { store.stopObserving() }
        #expect(await store.signIn(email: email, password: "s3cr3t") == .mfaRequired)
        #expect(store.pendingMFA == PendingMFA(token: "mfa-a1b2c3d4e5f6", email: email))
        #expect(store.session == .notConfigured)
        #expect(await store.completeMFA(code: "123456"))
        #expect(store.pendingMFA == nil)
        #expect(store.session == .active(.oauth(email: email)))
        #expect(store.status?.status == .running)
        #expect(store.profile?.name == "Maria Müller")
        let tokenRequests = await harness.transport.requests.filter { $0.url.path().hasSuffix("oauth2/token") }
        #expect(tokenRequests.count == 2)
        #expect(tokenRequests[1].bodyText == "grant_type=mfa_totp&mfa_token=mfa-a1b2c3d4e5f6&totp_code=123456&client_id=public")
    }

    @Test func wrongPasswordShowsMessage() async throws {
        let harness = try TestStore(credentials: nil, routes: ["oauth2/token": [.fixture(400, "oauth-error")]])
        let store = harness.store
        await store.start()
        defer { store.stopObserving() }
        #expect(await store.signIn(email: email, password: "wrong") == .failed)
        #expect(store.authError == "E-Mail-Adresse oder Passwort ist falsch.")
        #expect(store.session == .notConfigured)
    }

    @Test func expiredCodeReturnsToThePasswordForm() async throws {
        let expired = Data(#"{"error":"invalid_grant","error_description":"MFA token expired"}"#.utf8)
        let harness = try TestStore(credentials: nil, routes: ["oauth2/token": [.fixture(200, "oauth-mfa"), .raw(400, expired)]])
        let store = harness.store
        await store.start()
        defer { store.stopObserving() }
        _ = await store.signIn(email: email, password: "s3cr3t")
        #expect(await store.completeMFA(code: "123456") == false)
        #expect(store.authError == "Der Code ist abgelaufen. Bitte erneut anmelden.")
        #expect(store.pendingMFA == nil)
    }

    @Test func wrongCodeKeepsTheChallenge() async throws {
        let wrong = Data(#"{"error":"invalid_grant","error_description":"Invalid TOTP code"}"#.utf8)
        let harness = try TestStore(credentials: nil, routes: ["oauth2/token": [.fixture(200, "oauth-mfa"), .raw(400, wrong)]])
        let store = harness.store
        await store.start()
        defer { store.stopObserving() }
        _ = await store.signIn(email: email, password: "s3cr3t")
        #expect(await store.completeMFA(code: "000000") == false)
        #expect(store.authError == "Der Code aus der Authenticator-App war nicht korrekt.")
        #expect(store.pendingMFA != nil)
        store.cancelMFA()
        #expect(store.pendingMFA == nil)
        #expect(store.authError == nil)
    }

    @Test func signOutClearsCredentialsAndData() async throws {
        let harness = try TestStore(credentials: .apiToken("tb_secret"), routes: TestStore.running)
        let store = harness.store
        await store.start()
        defer { store.stopObserving() }
        await store.signOut()
        #expect(store.session == .notConfigured)
        #expect(store.status == nil)
        #expect(store.summary == nil)
        #expect(store.profile == nil)
        #expect(harness.credentialStore.stored == nil)
        #expect(!store.isAuthenticating)
    }
}
