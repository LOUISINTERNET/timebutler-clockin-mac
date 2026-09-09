/// Outcome of `POST /time-clock/stop`, including the 204 case for a `waiting` clock.
enum StopResult: Sendable, Equatable {
    case saved(SavedTimeEntry)
    case confirmationRequired(BreakRegulation)
    /// The clock was still `waiting`; Timebutler discarded it without a time entry.
    case discarded

    init(response: TimeClockStopResponse) {
        switch response {
        case .saved(let entry):
            self = .saved(entry)
        case .confirmationRequired(let regulation):
            self = .confirmationRequired(regulation)
        }
    }
}
