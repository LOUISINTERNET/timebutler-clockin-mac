/// What the UI needs to know about the stored credentials.
enum SessionState: Sendable, Equatable {
    case notConfigured
    case active(CredentialKind)
    /// Credentials exist but Timebutler no longer accepts them; the user has to sign in again.
    case expired

    var isActive: Bool {
        if case .active = self {
            return true
        }
        return false
    }
}
