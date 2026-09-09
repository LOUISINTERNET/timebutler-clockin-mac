import Foundation
import Testing

struct DurationFormattingTests {
    @Test(arguments: [(0, "0:00"), (59, "0:00"), (60, "0:01"), (3599, "0:59"), (3600, "1:00"), (27_120, "7:32"), (-30, "0:00")])
    func hoursMinutesFromSeconds(seconds: Int, expected: String) {
        #expect(DurationFormatting.hoursMinutes(seconds: seconds) == expected)
    }

    @Test(arguments: [(0, "0:00:00"), (59, "0:00:59"), (3599, "0:59:59"), (3600, "1:00:00"), (27_125, "7:32:05"), (-5, "0:00:00")])
    func hoursMinutesSecondsFromSeconds(seconds: Int, expected: String) {
        #expect(DurationFormatting.hoursMinutesSeconds(seconds: seconds) == expected)
    }

    @Test(arguments: [(0, "0:00"), (45, "0:45"), (-45, "-0:45"), (452, "7:32"), (-600, "-10:00")])
    func signedHoursMinutesFromMinutes(minutes: Int, expected: String) {
        #expect(DurationFormatting.signedHoursMinutes(minutes: minutes) == expected)
    }

    @Test func clockTimeUsesGivenTimeZone() throws {
        let berlin = try #require(TimeZone(identifier: "Europe/Berlin"))
        // 2025-07-28 11:00:00 UTC, which is 13:00 in Berlin (CEST).
        #expect(DurationFormatting.clockTime(millisecondsSince1970: 1_753_700_400_000, timeZone: berlin) == "13:00")
        let utc = try #require(TimeZone(identifier: "UTC"))
        #expect(DurationFormatting.clockTime(millisecondsSince1970: 1_753_700_400_000, timeZone: utc) == "11:00")
    }
}
