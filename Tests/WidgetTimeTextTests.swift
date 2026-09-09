import Foundation
import Testing

struct WidgetTimeTextTests {
    private let fetchedAt = Date(timeIntervalSince1970: 1_000_000)
    private let summary = WorkSummary(commitmentMinutes: 480, workedMinutes: 192, remainingMinutes: 288, percentDone: 40, breakMinutes: 30)

    @Test func runningShowsLiveWorkTime() throws {
        let running = try Fixture.decode(TimeClockStatus.self, from: "status-running")
        #expect(WidgetTimeText.main(status: running, summary: summary, fetchedAt: fetchedAt, now: fetchedAt.addingTimeInterval(65)) == "4:01:05")
    }

    @Test func pausedShowsTheRunningBreak() throws {
        let paused = try Fixture.decode(TimeClockStatus.self, from: "status-paused")
        #expect(WidgetTimeText.main(status: paused, summary: summary, fetchedAt: fetchedAt, now: fetchedAt.addingTimeInterval(30)) == "0:10:30")
    }

    @Test func waitingShowsWorkTimeWithoutTicking() throws {
        let waiting = try Fixture.decode(TimeClockStatus.self, from: "status-waiting")
        #expect(WidgetTimeText.main(status: waiting, summary: summary, fetchedAt: fetchedAt, now: fetchedAt.addingTimeInterval(500)) == "0:00:00")
    }

    @Test func compactLineNamesTheStartOfWorkOrBreak() throws {
        let berlin = try #require(TimeZone(identifier: "Europe/Berlin"))
        let running = try Fixture.decode(TimeClockStatus.self, from: "status-running")
        let paused = try Fixture.decode(TimeClockStatus.self, from: "status-paused")
        let idle = try Fixture.decode(TimeClockStatus.self, from: "status-idle")
        #expect(WidgetCompactView.since(status: running) == "seit \(DurationFormatting.clockTime(millisecondsSince1970: 1_753_700_400_000))")
        #expect(WidgetCompactView.since(status: paused) == "Pause seit \(DurationFormatting.clockTime(millisecondsSince1970: 1_753_714_800_000))")
        #expect(WidgetCompactView.since(status: idle) == "heute erfasst")
        #expect(DurationFormatting.clockTime(millisecondsSince1970: 1_753_714_800_000, timeZone: berlin) == "17:00")
    }

    @Test func idleShowsTodaysSavedTimeOrADash() throws {
        let idle = try Fixture.decode(TimeClockStatus.self, from: "status-idle")
        #expect(WidgetTimeText.main(status: idle, summary: summary, fetchedAt: fetchedAt, now: fetchedAt) == "3:12")
        #expect(WidgetTimeText.main(status: idle, summary: nil, fetchedAt: fetchedAt, now: fetchedAt) == "–")
    }
}
