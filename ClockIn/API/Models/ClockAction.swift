/// Commands of the `POST /time-clock/*` endpoints.
enum ClockAction: String, Sendable, Equatable, CaseIterable {
    case start
    case pause
    case resume
    case stop
    case cancel

    var path: String {
        "time-clock/\(rawValue)"
    }
}
