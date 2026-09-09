import Synchronization

/// Credential store fake for tests: keeps one record in memory and can be told to fail.
final class InMemoryCredentialStore: CredentialStore, Sendable {
    private struct State {
        var credentials: Credentials?
        var failure: KeychainError?
        var saveCount = 0
    }

    private let state: Mutex<State>

    init(_ credentials: Credentials? = nil) {
        state = Mutex(State(credentials: credentials))
    }

    var stored: Credentials? {
        state.withLock { $0.credentials }
    }

    var saveCount: Int {
        state.withLock { $0.saveCount }
    }

    func failAllCalls(with error: KeychainError) {
        state.withLock { $0.failure = error }
    }

    func load() throws -> Credentials? {
        try state.withLock { state in
            if let failure = state.failure {
                throw failure
            }
            return state.credentials
        }
    }

    func save(_ credentials: Credentials) throws {
        try state.withLock { state in
            if let failure = state.failure {
                throw failure
            }
            state.credentials = credentials
            state.saveCount += 1
        }
    }

    func delete() throws {
        try state.withLock { state in
            if let failure = state.failure {
                throw failure
            }
            state.credentials = nil
        }
    }
}
