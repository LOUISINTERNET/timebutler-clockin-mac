import Foundation
import Security
import Testing

/// Token refresh: sharing, rotation, failure modes and the races with sign-in and sign-out.
struct SessionManagerRefreshTests {
    @Test func parallelCallsShareOneRefresh() async throws {
        let store = InMemoryCredentialStore(.oauth(SessionManagerHarness.staleSession()))
        let (manager, transport) = try SessionManagerHarness.makeManager(store: store, replies: [.fixture(200, "oauth-token")])
        let tokens = try await withThrowingTaskGroup(of: String.self) { group in
            for _ in 0..<10 {
                group.addTask { try await manager.accessToken() }
            }
            return try await group.reduce(into: [String]()) { $0.append($1) }
        }
        #expect(tokens == Array(repeating: SessionManagerHarness.freshAccessToken, count: 10))
        #expect(await transport.requests.count == 1)
        #expect(store.stored == .oauth(OAuthSession(accessToken: SessionManagerHarness.freshAccessToken, refreshToken: "rt-a1b2c3d4e5f6", expiresAt: SessionManagerHarness.now.addingTimeInterval(3600), email: "user@example.com")))
        #expect(try await manager.accessToken() == SessionManagerHarness.freshAccessToken)
        #expect(await transport.requests.count == 1)
    }

    @Test func rejectedRefreshMarksSessionExpired() async throws {
        let store = InMemoryCredentialStore(.oauth(SessionManagerHarness.staleSession()))
        let (manager, _) = try SessionManagerHarness.makeManager(store: store, replies: [.fixture(400, "oauth-error")])
        let states = await manager.states()
        await #expect(throws: SessionError.expired) {
            try await manager.accessToken()
        }
        #expect(await manager.currentState() == .expired)
        #expect(store.stored == .oauth(SessionManagerHarness.staleSession()))
        var published: SessionState?
        for await state in states {
            published = state
            break
        }
        #expect(published == .expired)
    }

    @Test func keychainFailureDuringRefreshKeepsTheNewPairInMemory() async throws {
        let store = InMemoryCredentialStore(.oauth(SessionManagerHarness.staleSession()))
        let (manager, transport) = try SessionManagerHarness.makeManager(store: store, replies: [.fixture(200, "oauth-token")])
        store.failAllCalls(with: KeychainError(status: errSecAuthFailed))
        await #expect(throws: KeychainError(status: errSecAuthFailed)) {
            try await manager.accessToken()
        }
        #expect(await manager.currentState() == .active(.oauth(email: "user@example.com")))
        #expect(try await manager.accessToken() == SessionManagerHarness.freshAccessToken)
        #expect(await transport.requests.count == 1)
    }

    @Test func clientErrorDuringRefreshDoesNotExpire() async throws {
        let store = InMemoryCredentialStore(.oauth(SessionManagerHarness.staleSession()))
        let body = Data(#"{"error":"invalid_client","error_description":"Unknown client"}"#.utf8)
        let (manager, _) = try SessionManagerHarness.makeManager(store: store, replies: [.raw(400, body)])
        await #expect(throws: SessionError.oauth(status: 400, code: "invalid_client", description: "Unknown client")) {
            try await manager.accessToken()
        }
        #expect(await manager.currentState() == .active(.oauth(email: "user@example.com")))
    }

    @Test func expiredSessionDoesNotRecoverFromUnauthorized() async throws {
        let store = InMemoryCredentialStore(.oauth(SessionManagerHarness.staleSession()))
        let (manager, transport) = try SessionManagerHarness.makeManager(store: store, replies: [.fixture(200, "oauth-token")])
        await manager.markExpired()
        await #expect(throws: SessionError.expired) {
            try await manager.recoverFromUnauthorized()
        }
        #expect(await transport.requests.isEmpty)
    }

    @Test func transportFailureDuringRefreshDoesNotExpire() async throws {
        let store = InMemoryCredentialStore(.oauth(SessionManagerHarness.staleSession()))
        let (manager, _) = try SessionManagerHarness.makeManager(store: store, replies: [.failure(TransportError(description: "offline")), .fixture(200, "oauth-token")])
        await #expect(throws: SessionError.transport("offline")) {
            try await manager.accessToken()
        }
        #expect(await manager.currentState() == .active(.oauth(email: "user@example.com")))
        #expect(try await manager.accessToken() == SessionManagerHarness.freshAccessToken)
    }

    @Test func signOutDuringRefreshDoesNotResurrectCredentials() async throws {
        let store = InMemoryCredentialStore(.oauth(SessionManagerHarness.staleSession()))
        let (manager, transport) = try SessionManagerHarness.makeManager(store: store, replies: [.fixture(200, "oauth-token")])
        await transport.holdNextReply()
        let refresh = Task { try await manager.accessToken() }
        await transport.waitForRequests(count: 1)
        try await manager.signOut()
        await transport.releaseHeldReply()
        await #expect(throws: CancellationError.self) {
            try await refresh.value
        }
        #expect(store.stored == nil)
        #expect(store.saveCount == 0)
        #expect(await manager.currentState() == .notConfigured)
    }

    @Test func rejectedRefreshAfterNewSignInLeavesNewSessionActive() async throws {
        let store = InMemoryCredentialStore(.oauth(SessionManagerHarness.staleSession()))
        let (manager, transport) = try SessionManagerHarness.makeManager(store: store, replies: [.fixture(400, "oauth-error")])
        await transport.holdNextReply()
        let refresh = Task { try await manager.accessToken() }
        await transport.waitForRequests(count: 1)
        let profile = try Fixture.decode(UserProfile.self, from: "profile")
        _ = try await manager.signIn(apiToken: "tb_new") { _ in profile }
        await transport.releaseHeldReply()
        await #expect(throws: CancellationError.self) {
            try await refresh.value
        }
        #expect(await manager.currentState() == .active(.apiToken))
        #expect(try await manager.accessToken() == "tb_new")
        #expect(store.stored == .apiToken("tb_new"))
    }
}
