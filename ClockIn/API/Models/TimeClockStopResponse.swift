/// The saved time entry returned by `POST /time-clock/stop` with `outcome: saved`.
struct SavedTimeEntry: Decodable, Sendable, Equatable {
    let id: String
    let workedMinutes: Int
    let breakMinutes: Int
    let breakRegulationApplied: Bool
    let breakRegulationIgnored: Bool
}

/// `TimeClockStopResponse`, modelled as the union it is: the entry fields exist only
/// for `saved`, the regulation details only for `confirmationRequired`.
enum TimeClockStopResponse: Decodable, Sendable, Equatable {
    case saved(SavedTimeEntry)
    case confirmationRequired(BreakRegulation)

    private enum CodingKeys: String, CodingKey {
        case outcome
        case breakRegulation
    }

    private enum Outcome: String, Decodable {
        case saved
        case confirmationRequired
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(Outcome.self, forKey: .outcome) {
        case .saved:
            self = .saved(try SavedTimeEntry(from: decoder))
        case .confirmationRequired:
            self = .confirmationRequired(try container.decode(BreakRegulation.self, forKey: .breakRegulation))
        }
    }
}
