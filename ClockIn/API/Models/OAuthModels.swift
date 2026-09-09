/// Successful answer of `POST /oauth2/token`.
struct OAuthTokenResponse: Decodable, Sendable, Equatable {
    let accessToken: String
    let refreshToken: String
    let tokenType: String
    let expiresIn: Int
    let scope: String

    private enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
        case scope
    }
}

/// Answer of a `password` grant when the account has two-factor authentication enabled.
struct MfaChallengeResponse: Decodable, Sendable, Equatable {
    let mfaRequired: Bool
    let mfaToken: String
    let mfaExpiresIn: Int

    private enum CodingKeys: String, CodingKey {
        case mfaRequired = "mfa_required"
        case mfaToken = "mfa_token"
        case mfaExpiresIn = "mfa_expires_in"
    }
}

/// Error body of `POST /oauth2/token` (HTTP 400, 403, 429, 500).
struct OAuthErrorResponse: Decodable, Sendable, Equatable {
    let error: String
    let errorDescription: String

    private enum CodingKeys: String, CodingKey {
        case error
        case errorDescription = "error_description"
    }
}
