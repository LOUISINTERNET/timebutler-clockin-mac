import Foundation
import Security
import Testing

struct CredentialStoreTests {
    @Test func apiTokenRoundTrips() throws {
        let store = InMemoryCredentialStore()
        #expect(try store.load() == nil)
        try store.save(.apiToken("tb_secret"))
        #expect(try store.load() == .apiToken("tb_secret"))
        #expect(store.saveCount == 1)
    }

    @Test func oauthSessionRoundTripsThroughJSON() throws {
        let session = OAuthSession(accessToken: "access", refreshToken: "refresh", expiresAt: Date(timeIntervalSince1970: 1_800_000_000), email: "user@example.com")
        let data = try JSONEncoder().encode(Credentials.oauth(session))
        let decoded = try JSONDecoder().decode(Credentials.self, from: data)
        #expect(decoded == .oauth(session))
        #expect(decoded.kind == .oauth(email: "user@example.com"))
    }

    @Test func deleteClearsTheRecord() throws {
        let store = InMemoryCredentialStore(.apiToken("tb_secret"))
        try store.delete()
        #expect(try store.load() == nil)
        try store.delete()
    }

    @Test func failuresPropagate() {
        let store = InMemoryCredentialStore()
        store.failAllCalls(with: KeychainError(status: errSecAuthFailed))
        #expect(throws: KeychainError(status: errSecAuthFailed)) {
            try store.load()
        }
    }

    @Test func keychainErrorHasReadableDescription() {
        let error = KeychainError(status: errSecItemNotFound)
        #expect(error.errorDescription?.hasPrefix("Schlüsselbund-Fehler -25300") == true)
    }
}
