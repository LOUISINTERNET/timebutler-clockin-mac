import Foundation
import Security
import Testing

struct SessionManagerTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private let freshAccessToken = "eyJhbGciOiJSUzI1NiJ9.fixture-access-token"

    private func makeManager(store: InMemoryCredentialStore, replies: [FixtureTransport.Reply]) throws -> (SessionManager, FixtureTransport) {
        let transport = FixtureTransport(replies)
        let client = OAuthClient(transport: transport, now: { now })
        return (try SessionManager(credentialStore: store, oauthClient: client, now: { now }), transport)
    }

    private func staleSession(email: String = "user@example.com") -> OAuthSession {
        OAuthSession(accessToken: "old-access", refreshToken: "rt-old", expiresAt: now.addingTimeInterval(10), email: email)
    }

    @Test func apiTokenIsReturnedWithoutRefresh() async throws {
        let store = InMemoryCredentialStore(.apiToken("tb_secret"))
        let (manager, transport) = try makeManager(store: store, replies: [])
        #expect(try await manager.accessToken() == "tb_secret")
        #expect(try await manager.recoverFromUnauthorized() == nil)
        #expect(await manager.currentState() == .active(.apiToken))
        #expect(await transport.requests.isEmpty)
    }

    @Test func validOAuthTokenIsReturnedWithoutRefresh() async throws {
        let session = OAuthSession(accessToken: "valid", refreshToken: "rt", expiresAt: now.addingTimeInterval(600), email: "user@example.com")
        let (manager, transport) = try makeManager(store: InMemoryCredentialStore(.oauth(session)), replies: [])
        #expect(try await manager.accessToken() == "valid")
        #expect(await transport.requests.isEmpty)
    }

    @Test func parallelCallsShareOneRefresh() async throws {
        let store = InMemoryCredentialStore(.oauth(staleSession()))
        let (manager, transport) = try makeManager(store: store, replies: [.fixture(200, "oauth-token")])
        let tokens = try await withThrowingTaskGroup(of: String.self) { group in
            for _ in 0..<10 {
                group.addTask { try await manager.accessToken() }
            }
            return try await group.reduce(into: [String]()) { $0.append($1) }
        }
        #expect(tokens == Array(repeating: freshAccessToken, count: 10))
        #expect(await transport.requests.count == 1)
        #expect(store.stored == .oauth(OAuthSession(accessToken: freshAccessToken, refreshToken: "rt-a1b2c3d4e5f6", expiresAt: now.addingTimeInterval(3600), email: "user@example.com")))
        #expect(try await manager.accessToken() == freshAccessToken)
        #expect(await transport.requests.count == 1)
    }

    @Test func rejectedRefreshMarksSessionExpired() async throws {
        let store = InMemoryCredentialStore(.oauth(staleSession()))
        let (manager, _) = try makeManager(store: store, replies: [.fixture(400, "oauth-error")])
        let states = await manager.states()
        await #expect(throws: SessionError.expired) {
            try await manager.accessToken()
        }
        #expect(await manager.currentState() == .expired)
        #expect(store.stored == .oauth(staleSession()))
        var published: SessionState?
        for await state in states {
            published = state
            break
        }
        #expect(published == .expired)
    }

    @Test func keychainFailureDuringRefreshKeepsTheNewPairInMemory() async throws {
        let store = InMemoryCredentialStore(.oauth(staleSession()))
        let (manager, transport) = try makeManager(store: store, replies: [.fixture(200, "oauth-token")])
        store.failAllCalls(with: KeychainError(status: errSecAuthFailed))
        await #expect(throws: KeychainError(status: errSecAuthFailed)) {
            try await manager.accessToken()
        }
        #expect(await manager.currentState() == .active(.oauth(email: "user@example.com")))
        #expect(try await manager.accessToken() == freshAccessToken)
        #expect(await transport.requests.count == 1)
    }

    @Test func clientErrorDuringRefreshDoesNotExpire() async throws {
        let store = InMemoryCredentialStore(.oauth(staleSession()))
        let body = Data(#"{"error":"invalid_client","error_description":"Unknown client"}"#.utf8)
        let (manager, _) = try makeManager(store: store, replies: [.raw(400, body)])
        await #expect(throws: SessionError.oauth(status: 400, code: "invalid_client", description: "Unknown client")) {
            try await manager.accessToken()
        }
        #expect(await manager.currentState() == .active(.oauth(email: "user@example.com")))
    }

    @Test func expiredSessionDoesNotRecoverFromUnauthorized() async throws {
        let store = InMemoryCredentialStore(.oauth(staleSession()))
        let (manager, transport) = try makeManager(store: store, replies: [.fixture(200, "oauth-token")])
        await manager.markExpired()
        await #expect(throws: SessionError.expired) {
            try await manager.recoverFromUnauthorized()
        }
        #expect(await transport.requests.isEmpty)
    }

    @Test func transportFailureDuringRefreshDoesNotExpire() async throws {
        let store = InMemoryCredentialStore(.oauth(staleSession()))
        let (manager, _) = try makeManager(store: store, replies: [.failure(TransportError(description: "offline")), .fixture(200, "oauth-token")])
        await #expect(throws: SessionError.transport("offline")) {
            try await manager.accessToken()
        }
        #expect(await manager.currentState() == .active(.oauth(email: "user@example.com")))
        #expect(try await manager.accessToken() == freshAccessToken)
    }

    @Test func signOutDuringRefreshDoesNotResurrectCredentials() async throws {
        let store = InMemoryCredentialStore(.oauth(staleSession()))
        let (manager, transport) = try makeManager(store: store, replies: [.fixture(200, "oauth-token")])
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
        let store = InMemoryCredentialStore(.oauth(staleSession()))
        let (manager, transport) = try makeManager(store: store, replies: [.fixture(400, "oauth-error")])
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

    @Test func rejectedApiTokenLeavesCredentialsUntouched() async throws {
        let store = InMemoryCredentialStore(.apiToken("tb_old"))
        let (manager, _) = try makeManager(store: store, replies: [])
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
        let (manager, _) = try makeManager(store: store, replies: [])
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
        let (manager, _) = try makeManager(store: store, replies: [.fixture(200, "oauth-mfa"), .fixture(200, "oauth-token")])
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
        let (manager, _) = try makeManager(store: store, replies: [])
        try await manager.signOut()
        #expect(store.stored == nil)
        #expect(await manager.currentState() == .notConfigured)
        await #expect(throws: SessionError.notConfigured) {
            try await manager.accessToken()
        }
    }

    @Test func expiredSessionRejectsTokenRequestsUntilNewSignIn() async throws {
        let store = InMemoryCredentialStore(.apiToken("tb_secret"))
        let (manager, _) = try makeManager(store: store, replies: [.fixture(200, "oauth-token")])
        await manager.markExpired()
        await #expect(throws: SessionError.expired) {
            try await manager.accessToken()
        }
        _ = try await manager.signIn(email: "user@example.com", password: "s3cr3t")
        #expect(try await manager.accessToken() == freshAccessToken)
    }
}
