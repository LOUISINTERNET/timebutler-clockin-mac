import Foundation

/// Tokens obtained through `POST /oauth2/token`. The refresh token is single-use and
/// rotates on every refresh.
struct OAuthSession: Codable, Sendable, Equatable {
    let accessToken: String
    let refreshToken: String
    let expiresAt: Date
    let email: String
}

enum CredentialKind: Sendable, Equatable {
    case apiToken
    case oauth(email: String)
}

/// What is stored in the keychain: either a personal API token or an OAuth session.
enum Credentials: Codable, Sendable, Equatable {
    case apiToken(String)
    case oauth(OAuthSession)

    var kind: CredentialKind {
        switch self {
        case .apiToken:
            .apiToken
        case .oauth(let session):
            .oauth(email: session.email)
        }
    }
}
