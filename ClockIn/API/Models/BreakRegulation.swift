/// `TimeClockBreakRegulationInfo`, attached to a `confirmationRequired` stop response.
///
/// The flags and the summary text are always present. The four minute values describe
/// the correction Timebutler would apply; the spec ties them to "bei Übernahme der
/// Korrektur", so they are optional for violations that have no remedy (requirements EC-10).
struct BreakRegulation: Decodable, Sendable, Equatable {
    /// The violation cannot be fixed automatically; only cancel or (if not obligatory) ignore remain.
    let hasNoRemedy: Bool
    /// The regulation is mandatory for the company; `ignore` must not be offered.
    let obligatory: Bool
    let correctionWorkMinutes: Int?
    let correctionBreakMinutes: Int?
    let resultingWorkMinutes: Int?
    let resultingBreakMinutes: Int?
    /// Localized, human-readable summary of the required change.
    let detailText: String
}
