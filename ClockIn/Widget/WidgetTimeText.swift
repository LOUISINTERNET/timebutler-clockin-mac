import Foundation

/// The one number the widget is about (FR-C3): net work time while running or waiting,
/// the running break while paused, today's saved time while idle.
enum WidgetTimeText {
    static func main(status: TimeClockStatus, summary: WorkSummary?, fetchedAt: Date, now: Date) -> String {
        switch status.status {
        case .running, .waiting:
            DurationFormatting.hoursMinutesSeconds(seconds: LiveClock.workSeconds(status: status, fetchedAt: fetchedAt, now: now))
        case .paused:
            DurationFormatting.hoursMinutesSeconds(seconds: LiveClock.breakSeconds(status: status, fetchedAt: fetchedAt, now: now))
        case .idle:
            summary.map { DurationFormatting.signedHoursMinutes(minutes: $0.workedMinutes) } ?? "–"
        }
    }
}
