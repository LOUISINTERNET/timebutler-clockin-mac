import Foundation

enum SignInStep: Sendable, Equatable {
    case signedIn
    case mfaRequired
    case failed
}

/// Sign-in and sign-out for the settings window. Every method delegates to the session
/// manager, reports failures through `authError` and re-reads the session afterwards.
extension ClockStore {
    static let rejectedTokenMessage = "Der API-Token wurde von Timebutler nicht akzeptiert."

    /// FR-S2: the token is checked with `GET /user/profile` before it is stored. Timebutler
    /// answers 401 for a bad token and 403 for an IP restriction; both mean "not accepted".
    @discardableResult
    func signIn(apiToken: String) async -> Bool {
        beginAuthentication()
        defer { isAuthenticating = false }
        do {
            profile = try await sessionManager.signIn(apiToken: apiToken) { [api] token in
                try await api.authenticating(with: token).profile()
            }
            await synchronizeSession()
            return true
        } catch APIError.http(let code, _, _) where code == 401 || code == 403 {
            authError = Self.rejectedTokenMessage
            return false
        } catch {
            authError = message(for: error)
            return false
        }
    }

    func signIn(email: String, password: String) async -> SignInStep {
        beginAuthentication()
        defer { isAuthenticating = false }
        do {
            switch try await sessionManager.signIn(email: email, password: password) {
            case .signedIn:
                await synchronizeSession()
                return .signedIn
            case .mfaRequired(let mfaToken, _):
                pendingMFA = PendingMFA(token: mfaToken, email: email)
                return .mfaRequired
            }
        } catch {
            authError = message(for: error)
            return .failed
        }
    }

    /// FR-S3, EC-3: an expired challenge sends the form back to e-mail and password.
    @discardableResult
    func completeMFA(code: String) async -> Bool {
        guard let pendingMFA else {
            preconditionFailure("completeMFA(code:) called without a pending challenge")
        }
        beginAuthentication()
        defer { isAuthenticating = false }
        do {
            _ = try await sessionManager.completeMFA(mfaToken: pendingMFA.token, code: code, email: pendingMFA.email)
            self.pendingMFA = nil
            await synchronizeSession()
            return true
        } catch {
            authError = message(for: error)
            if let sessionError = error as? SessionError, sessionError.isExpiredChallenge {
                self.pendingMFA = nil
            }
            return false
        }
    }

    func cancelMFA() {
        pendingMFA = nil
        authError = nil
    }

    /// FR-S8: removes the credentials and, through the session state, every status value.
    func signOut() async {
        beginAuthentication()
        defer { isAuthenticating = false }
        do {
            try await sessionManager.signOut()
        } catch {
            authError = message(for: error)
        }
        pendingMFA = nil
        await synchronizeSession()
    }

    private func beginAuthentication() {
        isAuthenticating = true
        authError = nil
    }
}
