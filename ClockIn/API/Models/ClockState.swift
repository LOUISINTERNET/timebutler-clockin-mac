/// State of the Timebutler time clock as reported by `GET /time-clock/status`.
enum ClockState: String, Codable, Sendable, Equatable {
    case idle
    case running
    case paused
    /// Started, but held back by the server until a configured minimum interval has passed.
    case waiting

    var germanLabel: String {
        switch self {
        case .idle: "Gestoppt"
        case .running: "Läuft"
        case .paused: "Pause"
        case .waiting: "Wartet"
        }
    }

    /// A clock session exists (running, paused or waiting).
    var isActive: Bool {
        self != .idle
    }
}
