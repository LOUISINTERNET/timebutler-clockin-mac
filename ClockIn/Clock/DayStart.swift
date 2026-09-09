import Foundation

/// The first clock-in of the day, taken from the saved entries (FR-C2: "seit 17:27 (08:37)").
enum DayStart {
    /// The earliest `startTime` of the entries dated `today`, or nil when there is none.
    static func firstStart(entries: [TimeEntry], today: String) -> String? {
        entries
            .filter { $0.date == today }
            .compactMap(\.startTime)
            .min()
    }

    /// "2026-09-09" for the given moment in the given time zone.
    static func dayString(for date: Date, timeZone: TimeZone = .current) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        guard let year = components.year, let month = components.month, let day = components.day else {
            preconditionFailure("Calendar returned no date components for \(date)")
        }
        return String(format: "%04d-%02d-%02d", year, month, day)
    }

    /// "seit 17:27 (08:37)" while the day started earlier, "seit 08:37" for the first session.
    static func sinceText(prefix: String, currentStart: Int64, firstStart: String?) -> String {
        let current = DurationFormatting.clockTime(millisecondsSince1970: currentStart)
        if let firstStart, firstStart < current {
            return "\(prefix) \(current) (\(firstStart))"
        }
        return "\(prefix) \(current)"
    }
}
