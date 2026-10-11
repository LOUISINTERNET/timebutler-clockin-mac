import Foundation
import os

enum LoginResult: Sendable, Equatable {
    case signedIn(OAuthSession)
    case mfaRequired(mfaToken: String, expiresIn: Int)
}

/// `POST /oauth2/token` for the password, mfa_totp and refresh_token grants.
struct OAuthClient: Sendable {
    static let clientIdentifier = "public"

    private let transport: any HTTPTransport
    private let baseURL: URL
    private let now: @Sendable () -> Date
    private let logger = Log.logger(.session)

    init(transport: any HTTPTransport, baseURL: URL = TimebutlerAPI.defaultBaseURL, now: @escaping @Sendable () -> Date = Date.init) {
        self.transport = transport
        self.baseURL = baseURL
        self.now = now
    }

    func signIn(email: String, password: String) async throws -> LoginResult {
        logger.notice("Password grant for \(email, privacy: .private)")
        let outcome = try await token(fields: [
            (name: "grant_type", value: "password"),
            (name: "username", value: email),
            (name: "password", value: password),
            (name: "client_id", value: Self.clientIdentifier),
        ])
        switch outcome {
        case .tokens(let response):
            return .signedIn(session(from: response, email: email))
        case .mfaChallenge(let challenge):
            logger.notice("Two-factor challenge received, expires in \(challenge.mfaExpiresIn, privacy: .public) s")
            return .mfaRequired(mfaToken: challenge.mfaToken, expiresIn: challenge.mfaExpiresIn)
        }
    }

    func completeMFA(mfaToken: String, code: String, email: String) async throws -> OAuthSession {
        logger.notice("Completing two-factor sign-in for \(email, privacy: .private)")
        let outcome = try await token(fields: [
            (name: "grant_type", value: "mfa_totp"),
            (name: "mfa_token", value: mfaToken),
            (name: "totp_code", value: code),
            (name: "client_id", value: Self.clientIdentifier),
        ])
        return try session(fromTokensOnly: outcome, email: email)
    }

    /// Exchanges the single-use refresh token for a new token pair.
    func refresh(session: OAuthSession) async throws -> OAuthSession {
        logger.notice("Refreshing access token for \(session.email, privacy: .private)")
        let outcome = try await token(fields: [
            (name: "grant_type", value: "refresh_token"),
            (name: "refresh_token", value: session.refreshToken),
            (name: "client_id", value: Self.clientIdentifier),
        ])
        return try self.session(fromTokensOnly: outcome, email: session.email)
    }

    private func session(fromTokensOnly outcome: TokenEndpointResponse, email: String) throws -> OAuthSession {
        guard case .tokens(let response) = outcome else {
            logger.error("Token endpoint answered with a second MFA challenge")
            throw SessionError.unreadableResponse
        }
        return session(from: response, email: email)
    }

    private func session(from response: OAuthTokenResponse, email: String) -> OAuthSession {
        OAuthSession(
            accessToken: response.accessToken,
            refreshToken: response.refreshToken,
            expiresAt: now().addingTimeInterval(Double(response.expiresIn)),
            email: email
        )
    }

    private func token(fields: [(name: String, value: String)]) async throws -> TokenEndpointResponse {
        var request = URLRequest(url: baseURL.appending(path: "oauth2/token"))
        request.httpMethod = HTTPMethod.post.rawValue
        request.timeoutInterval = 25
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = FormEncoding.encode(fields)

        let response: HTTPResponse
        do {
            response = try await transport.send(request)
        } catch let error as TransportError {
            logger.error("Token endpoint transport failure: \(error.description, privacy: .public)")
            throw SessionError.transport(error.description)
        }
        guard response.statusCode == 200 else {
            throw oauthError(status: response.statusCode, body: response.body)
        }
        do {
            return try JSONDecoder().decode(TokenEndpointResponse.self, from: response.body)
        } catch {
            logger.error("Unreadable token response (\(response.body.count, privacy: .public) bytes): \(String(describing: error), privacy: .public)")
            throw SessionError.unreadableResponse
        }
    }

    private func oauthError(status: Int, body: Data) -> SessionError {
        do {
            let errorResponse = try JSONDecoder().decode(OAuthErrorResponse.self, from: body)
            logger.error("Token endpoint HTTP \(status, privacy: .public): \(errorResponse.error, privacy: .public) \(errorResponse.errorDescription, privacy: .public)")
            return .oauth(status: status, code: errorResponse.error, description: errorResponse.errorDescription)
        } catch {
            logger.error("Token endpoint HTTP \(status, privacy: .public) with unreadable error body: \(String(describing: error), privacy: .public)")
            return .oauth(status: status, code: "", description: "")
        }
    }
}

/// The token endpoint answers 200 with either a token pair or an MFA challenge.
private enum TokenEndpointResponse: Decodable {
    case tokens(OAuthTokenResponse)
    case mfaChallenge(MfaChallengeResponse)

    private enum CodingKeys: String, CodingKey {
        case mfaRequired = "mfa_required"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if try container.decodeIfPresent(Bool.self, forKey: .mfaRequired) == true {
            self = .mfaChallenge(try MfaChallengeResponse(from: decoder))
        } else {
            self = .tokens(try OAuthTokenResponse(from: decoder))
        }
    }
}
