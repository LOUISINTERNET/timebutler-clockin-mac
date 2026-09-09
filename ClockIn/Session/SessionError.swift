import Foundation

/// Failures of sign-in, token refresh and credential storage, with German user texts.
enum SessionError: Error, Equatable, Sendable, LocalizedError {
    case notConfigured
    case expired
    case transport(String)
    case unreadableResponse
    /// Non-200 answer of the token endpoint. `code` and `description` are empty when the
    /// error body could not be decoded.
    case oauth(status: Int, code: String, description: String)

    var errorDescription: String? {
        userMessage
    }

    /// The token endpoint rejected the grant itself (password, code or refresh token). Other
    /// 400s such as `invalid_client` are client bugs and must not expire the session.
    var isRejectedGrant: Bool {
        if case .oauth(let status, let code, _) = self {
            return status == 400 && code == "invalid_grant"
        }
        return false
    }

    /// The MFA token ran out before the authenticator code arrived (EC-3).
    var isExpiredChallenge: Bool {
        if case .oauth(_, _, let description) = self {
            return description.lowercased().contains("expired")
        }
        return false
    }

    var userMessage: String {
        switch self {
        case .notConfigured:
            "Nicht angemeldet."
        case .expired:
            "Sitzung abgelaufen. Bitte neu anmelden."
        case .transport:
            "Keine Verbindung zu Timebutler."
        case .unreadableResponse:
            "Antwort von Timebutler nicht lesbar."
        case .oauth(let status, let code, let description):
            isExpiredChallenge ? "Der Code ist abgelaufen. Bitte erneut anmelden." : Self.oauthMessage(status: status, code: code, description: description)
        }
    }

    private static func oauthMessage(status: Int, code: String, description: String) -> String {
        let lowered = description.lowercased()
        if lowered.contains("totp") || lowered.contains("mfa") {
            return "Der Code aus der Authenticator-App war nicht korrekt."
        }
        if code == "invalid_grant" {
            return "E-Mail-Adresse oder Passwort ist falsch."
        }
        switch status {
        case 403: return "Zugriff durch IP-Beschränkung verweigert."
        case 429: return "Zu viele Versuche. Bitte in einer Minute erneut versuchen."
        case 500: return "Timebutler meldet einen Serverfehler."
        default: return "Anmeldung fehlgeschlagen (HTTP \(status))."
        }
    }
}
