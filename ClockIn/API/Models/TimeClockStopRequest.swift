/// How to resolve a break-regulation violation when stopping the clock.
enum BreakRegulationDecision: String, Codable, Sendable, Equatable {
    /// Let Timebutler shorten the work time so the regulation is satisfied.
    case apply
    /// Save the entry unchanged; only allowed when the regulation is not obligatory.
    case ignore
}

/// Body of `POST /time-clock/stop`. Project and category are sent as 0, which the
/// predecessor client has used in production (design decision D8).
struct TimeClockStopRequest: Encodable, Sendable, Equatable {
    let projectId: Int
    let categoryId: Int
    let breakRegulation: BreakRegulationDecision?

    static func standard(decision: BreakRegulationDecision? = nil) -> TimeClockStopRequest {
        TimeClockStopRequest(projectId: 0, categoryId: 0, breakRegulation: decision)
    }
}
