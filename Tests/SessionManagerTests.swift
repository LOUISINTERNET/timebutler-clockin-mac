import Foundation
import Security
import Testing

struct SessionManagerTests {
    @Test func apiTokenIsReturnedWithoutRefresh() async throws {
        let store = InMemoryCredentialStore(.apiToken("tb_secret"))
        let (manager, transport) = try SessionManagerHarness.makeManager(store: store, replies: [])
        #expect(try await manager.accessToken() == "tb_secret")
        #expect(try await manager.recoverFromUnauthorized() == nil)
        #expect(await manager.currentState() == .active(.apiToken))
        #expect(await transport.requests.isEmpty)
    }

    @Test func validOAuthTokenIsReturnedWithoutRefresh() async throws {
        let session = OAuthSession(accessToken: "valid", refreshToken: "rt", expiresAt: SessionManagerHarness.now.addingTimeInterval(600), email: "user@example.com")
        let (manager, transport) = try SessionManagerHarness.makeManager(store: InMemoryCredentialStore(.oauth(session)), replies: [])
        #expect(try await manager.accessToken() == "valid")
        #expect(await transport.requests.isEmpty)
    }

    @Test func rejectedApiTokenLeavesCredentialsUntouched() async throws {
        let store = InMemoryCredentialStore(.apiToken("tb_old"))
        let (manager, _) = try SessionManagerHarness.makeManager(store: store, replies: [])
        await #expect(throws: APIError.http(status: 401, action: nil, detail: "")) {
            try await manager.signIn(apiToken: " tb_new ") { _ in
                throw APIError.http(status: 401, action: nil, detail: "")
            }
        }
        #expect(store.stored == .apiToken("tb_old"))
        #expect(store.saveCount == 0)
    }

    @Test func acceptedApiTokenIsTrimmedAndStored() async throws {
        let store = InMemoryCredentialStore()
        let (manager, _) = try SessionManagerHarness.makeManager(store: store, replies: [])
        let profile = try Fixture.decode(UserProfile.self, from: "profile")
        let verified = try await manager.signIn(apiToken: " tb_new\n") { token in
            #expect(token == "tb_new")
            return profile
        }
        #expect(verified == profile)
        #expect(store.stored == .apiToken("tb_new"))
        #expect(await manager.currentState() == .active(.apiToken))
    }

    @Test func passwordSignInWithMfaStoresOnlyAfterCompletion() async throws {
        let store = InMemoryCredentialStore()
        let (manager, _) = try SessionManagerHarness.makeManager(store: store, replies: [.fixture(200, "oauth-mfa"), .fixture(200, "oauth-token")])
        let result = try await manager.signIn(email: "user@example.com", password: "s3cr3t")
        #expect(result == .mfaRequired(mfaToken: "mfa-a1b2c3d4e5f6", expiresIn: 300))
        #expect(store.stored == nil)
        #expect(await manager.currentState() == .notConfigured)
        let session = try await manager.completeMFA(mfaToken: "mfa-a1b2c3d4e5f6", code: "123456", email: "user@example.com")
        #expect(store.stored == .oauth(session))
        #expect(await manager.currentState() == .active(.oauth(email: "user@example.com")))
    }

    @Test func signOutDeletesCredentials() async throws {
        let store = InMemoryCredentialStore(.apiToken("tb_secret"))
        let (manager, _) = try SessionManagerHarness.makeManager(store: store, replies: [])
        try await manager.signOut()
        #expect(store.stored == nil)
        #expect(await manager.currentState() == .notConfigured)
        await #expect(throws: SessionError.notConfigured) {
            try await manager.accessToken()
        }
    }

    @Test func expiredSessionRejectsTokenRequestsUntilNewSignIn() async throws {
        let store = InMemoryCredentialStore(.apiToken("tb_secret"))
        let (manager, _) = try SessionManagerHarness.makeManager(store: store, replies: [.fixture(200, "oauth-token")])
        await manager.markExpired()
        await #expect(throws: SessionError.expired) {
            try await manager.accessToken()
        }
        _ = try await manager.signIn(email: "user@example.com", password: "s3cr3t")
        #expect(try await manager.accessToken() == SessionManagerHarness.freshAccessToken)
    }
}
