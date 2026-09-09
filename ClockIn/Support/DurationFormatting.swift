import Foundation

/// Text formats for durations and clock times as shown in the widget and menu bar.
enum DurationFormatting {
    /// "7:32" from seconds; negative input is treated as zero.
    static func hoursMinutes(seconds: Int) -> String {
        signedHoursMinutes(minutes: max(0, seconds) / 60)
    }

    /// "0:07:32" from seconds; negative input is treated as zero.
    static func hoursMinutesSeconds(seconds: Int) -> String {
        let total = max(0, seconds)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let remainingSeconds = total % 60
        return "\(hours):\(twoDigits(minutes)):\(twoDigits(remainingSeconds))"
    }

    /// "7:32" from minutes; negative values keep their sign ("-0:45").
    static func signedHoursMinutes(minutes: Int) -> String {
        let sign = minutes < 0 ? "-" : ""
        let magnitude = abs(minutes)
        return "\(sign)\(magnitude / 60):\(twoDigits(magnitude % 60))"
    }

    /// "14:32" in the local time zone from a Unix timestamp in milliseconds.
    static func clockTime(millisecondsSince1970: Int64, timeZone: TimeZone = .current) -> String {
        let date = Date(timeIntervalSince1970: Double(millisecondsSince1970) / 1000)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let components = calendar.dateComponents([.hour, .minute], from: date)
        guard let hour = components.hour, let minute = components.minute else {
            preconditionFailure("Calendar returned no hour or minute for \(date) in \(timeZone.identifier)")
        }
        return "\(twoDigits(hour)):\(twoDigits(minute))"
    }

    private static func twoDigits(_ value: Int) -> String {
        value < 10 ? "0\(value)" : "\(value)"
    }
}
