import Foundation
import Testing

struct DayStartTests {
    @Test func earliestStartOfTodayWins() throws {
        let entries = try Fixture.decode([TimeEntry].self, from: "time-entries")
        #expect(DayStart.firstStart(entries: entries, today: "2027-01-15") == "08:37")
        #expect(DayStart.firstStart(entries: entries, today: "2027-01-14") == "07:55")
        #expect(DayStart.firstStart(entries: entries, today: "2027-01-16") == nil)
    }

    @Test func entriesWithoutTimesAreIgnored() {
        let entries = [TimeEntry(date: "2027-01-15", startTime: nil, endTime: nil), TimeEntry(date: nil, startTime: "06:00", endTime: nil)]
        #expect(DayStart.firstStart(entries: entries, today: "2027-01-15") == nil)
    }

    @Test func dayStringUsesTheGivenTimeZone() throws {
        let berlin = try #require(TimeZone(identifier: "Europe/Berlin"))
        // 2025-07-28 23:30 UTC is already 2025-07-29 in Berlin.
        let late = Date(timeIntervalSince1970: 1_753_745_400)
        #expect(DayStart.dayString(for: late, timeZone: berlin) == "2025-07-29")
        #expect(DayStart.dayString(for: late, timeZone: try #require(TimeZone(identifier: "UTC"))) == "2025-07-28")
    }

    @Test func sinceTextAddsTheDayStartOnlyWhenEarlier() {
        let start = Int64(1_753_700_400_000)
        let current = DurationFormatting.clockTime(millisecondsSince1970: start)
        #expect(DayStart.sinceText(prefix: "seit", currentStart: start, firstStart: "06:15") == "seit \(current) (06:15)")
        #expect(DayStart.sinceText(prefix: "seit", currentStart: start, firstStart: current) == "seit \(current)")
        #expect(DayStart.sinceText(prefix: "Pause seit", currentStart: start, firstStart: nil) == "Pause seit \(current)")
    }
}
