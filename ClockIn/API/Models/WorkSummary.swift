/// `WorkSummaryResponse` for today. Counts only saved time entries; the running
/// session has to be added on top (see `WorkSummary+Live.swift`).
struct WorkSummary: Codable, Sendable, Equatable {
    let commitmentMinutes: Int
    let workedMinutes: Int
    let remainingMinutes: Int
    let percentDone: Int
    let breakMinutes: Int
}
