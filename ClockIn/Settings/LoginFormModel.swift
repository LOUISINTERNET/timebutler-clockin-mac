import Foundation
import Observation

enum LoginMethod: String, CaseIterable, Identifiable, Sendable {
    case apiToken
    case password

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .apiToken: "API-Token"
        case .password: "E-Mail & Passwort"
        }
    }
}

/// State of the sign-in form in the account tab (FR-P2). Password and code are cleared
/// with every submit; the token stays until it was accepted, so a typo can be corrected.
@MainActor
@Observable
final class LoginFormModel {
    var method: LoginMethod = .apiToken
    var email = ""
    var password = ""
    var apiToken = ""
    var totpCode = ""

    private let store: ClockStore

    init(store: ClockStore) {
        self.store = store
    }

    var isBusy: Bool {
        store.isAuthenticating
    }

    var errorMessage: String? {
        store.authError
    }

    /// A password sign-in is waiting for the authenticator code (FR-S3).
    var awaitingCode: Bool {
        store.pendingMFA != nil
    }

    var canSubmit: Bool {
        guard !isBusy else {
            return false
        }
        if awaitingCode {
            return totpCode.count == 6 && totpCode.allSatisfy(\.isNumber)
        }
        switch method {
        case .apiToken:
            return !apiToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .password:
            return !email.trimmingCharacters(in: .whitespaces).isEmpty && !password.isEmpty
        }
    }

    func submit() async {
        guard canSubmit else {
            return
        }
        if awaitingCode {
            let code = totpCode
            totpCode = ""
            await store.completeMFA(code: code)
            return
        }
        switch method {
        case .apiToken:
            if await store.signIn(apiToken: apiToken) {
                apiToken = ""
            }
        case .password:
            let secret = password
            password = ""
            _ = await store.signIn(email: email, password: secret)
        }
    }

    /// "Abbrechen" on the code step: back to e-mail and password (EC-3).
    func cancelCode() {
        totpCode = ""
        store.cancelMFA()
    }
}
