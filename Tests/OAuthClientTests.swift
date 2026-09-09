import Foundation
import Testing

struct OAuthClientTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func makeClient(_ replies: [FixtureTransport.Reply]) -> (OAuthClient, FixtureTransport) {
        let transport = FixtureTransport(replies)
        return (OAuthClient(transport: transport, now: { now }), transport)
    }

    @Test func passwordGrantReturnsSession() async throws {
        let (client, transport) = makeClient([.fixture(200, "oauth-token")])
        let result = try await client.signIn(email: "user@example.com", password: "s3cr3t")
        let expected = OAuthSession(accessToken: "eyJhbGciOiJSUzI1NiJ9.fixture-access-token", refreshToken: "rt-a1b2c3d4e5f6", expiresAt: now.addingTimeInterval(3600), email: "user@example.com")
        #expect(result == .signedIn(expected))
        let request = try #require(await transport.requests.first)
        #expect(request.method == "POST")
        #expect(request.url.path() == "/api/v2/oauth2/token")
        #expect(request.headers["Content-Type"] == "application/x-www-form-urlencoded")
        #expect(request.bodyText == "grant_type=password&username=user%40example.com&password=s3cr3t&client_id=public")
    }

    @Test func passwordGrantCanReturnMfaChallenge() async throws {
        let (client, _) = makeClient([.fixture(200, "oauth-mfa")])
        let result = try await client.signIn(email: "user@example.com", password: "s3cr3t")
        #expect(result == .mfaRequired(mfaToken: "mfa-a1b2c3d4e5f6", expiresIn: 300))
    }

    @Test func mfaCompletionSendsTokenAndCode() async throws {
        let (client, transport) = makeClient([.fixture(200, "oauth-token")])
        let session = try await client.completeMFA(mfaToken: "mfa-a1b2c3d4e5f6", code: "123456", email: "user@example.com")
        #expect(session.email == "user@example.com")
        let request = try #require(await transport.requests.first)
        #expect(request.bodyText == "grant_type=mfa_totp&mfa_token=mfa-a1b2c3d4e5f6&totp_code=123456&client_id=public")
    }

    @Test func refreshRotatesTokensAndKeepsEmail() async throws {
        let (client, transport) = makeClient([.fixture(200, "oauth-token")])
        let stale = OAuthSession(accessToken: "old-access", refreshToken: "rt-old", expiresAt: now, email: "user@example.com")
        let fresh = try await client.refresh(session: stale)
        #expect(fresh.refreshToken == "rt-a1b2c3d4e5f6")
        #expect(fresh.accessToken == "eyJhbGciOiJSUzI1NiJ9.fixture-access-token")
        #expect(fresh.email == "user@example.com")
        #expect(fresh.expiresAt == now.addingTimeInterval(3600))
        let request = try #require(await transport.requests.first)
        #expect(request.bodyText == "grant_type=refresh_token&refresh_token=rt-old&client_id=public")
    }

    @Test func specialCharactersArePercentEncoded() async throws {
        let (client, transport) = makeClient([.fixture(200, "oauth-token")])
        _ = try await client.signIn(email: "a+b@example.com", password: "pä ss&wörd=1")
        let request = try #require(await transport.requests.first)
        #expect(request.bodyText == "grant_type=password&username=a%2Bb%40example.com&password=p%C3%A4%20ss%26w%C3%B6rd%3D1&client_id=public")
    }

    @Test func rejectedGrantCarriesCodeAndMessage() async throws {
        let (client, _) = makeClient([.fixture(400, "oauth-error")])
        do {
            _ = try await client.signIn(email: "user@example.com", password: "wrong")
            Issue.record("expected an error")
        } catch let error as SessionError {
            #expect(error == .oauth(status: 400, code: "invalid_grant", description: "Invalid username or password"))
            #expect(error.isRejectedGrant)
            #expect(error.userMessage == "E-Mail-Adresse oder Passwort ist falsch.")
        }
    }

    @Test func statusMessagesFollowTheTable() {
        #expect(SessionError.oauth(status: 403, code: "", description: "").userMessage == "Zugriff durch IP-Beschränkung verweigert.")
        #expect(SessionError.oauth(status: 429, code: "", description: "").userMessage == "Zu viele Versuche. Bitte in einer Minute erneut versuchen.")
        #expect(SessionError.oauth(status: 500, code: "", description: "").userMessage == "Timebutler meldet einen Serverfehler.")
        #expect(SessionError.oauth(status: 400, code: "invalid_grant", description: "Invalid TOTP code").userMessage == "Der Code aus der Authenticator-App war nicht korrekt.")
        #expect(SessionError.oauth(status: 400, code: "invalid_grant", description: "MFA token expired").userMessage == "Der Code ist abgelaufen. Bitte erneut anmelden.")
        #expect(SessionError.transport("offline").userMessage == "Keine Verbindung zu Timebutler.")
        #expect(SessionError.expired.userMessage == "Sitzung abgelaufen. Bitte neu anmelden.")
    }

    @Test func mfaRequiredFalseIsATokenResponse() async throws {
        let body = Data(#"{"mfa_required":false,"access_token":"a","refresh_token":"r","token_type":"Bearer","expires_in":60,"scope":"read"}"#.utf8)
        let (client, _) = makeClient([.raw(200, body)])
        let result = try await client.signIn(email: "user@example.com", password: "s3cr3t")
        #expect(result == .signedIn(OAuthSession(accessToken: "a", refreshToken: "r", expiresAt: now.addingTimeInterval(60), email: "user@example.com")))
    }

    @Test func unreadableErrorBodyStillMapsByStatus() async throws {
        let (client, _) = makeClient([.raw(429, Data("<html>rate limited</html>".utf8))])
        await #expect(throws: SessionError.oauth(status: 429, code: "", description: "")) {
            try await client.signIn(email: "user@example.com", password: "x")
        }
    }

    @Test func transportFailureAndGarbageAreMapped() async throws {
        let (client, _) = makeClient([.failure(TransportError(description: "offline")), .raw(200, Data("not json".utf8))])
        await #expect(throws: SessionError.transport("offline")) {
            try await client.signIn(email: "user@example.com", password: "x")
        }
        await #expect(throws: SessionError.unreadableResponse) {
            try await client.signIn(email: "user@example.com", password: "x")
        }
    }
}
