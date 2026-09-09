/// One saved entry of `GET /time-entries/my`. Only the fields the widget needs are decoded;
/// all of them are optional because Timebutler omits fields in practice (EC-11, EC-12).
struct TimeEntry: Decodable, Sendable, Equatable {
    /// "2025-07-28"
    let date: String?
    /// "08:00", nil for entries without a clock time.
    let startTime: String?
    let endTime: String?
}
