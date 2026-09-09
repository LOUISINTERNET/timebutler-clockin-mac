import Foundation
import Security

/// Persistent storage for the one credentials record of this app.
protocol CredentialStore: Sendable {
    func load() throws -> Credentials?
    func save(_ credentials: Credentials) throws
    func delete() throws
}

struct KeychainError: Error, Equatable, Sendable, LocalizedError {
    let status: OSStatus

    var errorDescription: String? {
        message
    }

    var message: String {
        if let reason = SecCopyErrorMessageString(status, nil) as String? {
            return "Schlüsselbund-Fehler \(status): \(reason)"
        }
        return "Schlüsselbund-Fehler \(status)"
    }
}
