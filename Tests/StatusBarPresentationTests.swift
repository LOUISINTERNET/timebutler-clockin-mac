import Foundation
import Testing

struct StatusBarPresentationTests {
    private let fetchedAt = Date(timeIntervalSince1970: 1_000_000)

    @Test func signedOutStatesShowTheWarningSymbolWithoutTitle() {
        let expected = StatusBarPresentation(symbolName: "clock.badge.exclamationmark", title: "")
        #expect(StatusBarPresentation.make(session: .notConfigured, status: nil, fetchedAt: nil, now: fetchedAt) == expected)
        #expect(StatusBarPresentation.make(session: .expired, status: nil, fetchedAt: nil, now: fetchedAt) == expected)
    }

    @Test func activeSessionWithoutStatusShowsThePlainClock() {
        let presentation = StatusBarPresentation.make(session: .active(.apiToken), status: nil, fetchedAt: nil, now: fetchedAt)
        #expect(presentation == StatusBarPresentation(symbolName: "clock", title: ""))
    }

    @Test func idleShowsNoTitle() throws {
        let idle = try Fixture.decode(TimeClockStatus.self, from: "status-idle")
        let presentation = StatusBarPresentation.make(session: .active(.apiToken), status: idle, fetchedAt: fetchedAt, now: fetchedAt)
        #expect(presentation == StatusBarPresentation(symbolName: "clock", title: ""))
    }

    @Test func runningShowsLiveWorkTimeAndFlipsAtTheFullMinute() throws {
        let running = try Fixture.decode(TimeClockStatus.self, from: "status-running")
        let session = SessionState.active(.oauth(email: "user@example.com"))
        // 14400 s on the server; 59 s later it is still 4:00, 60 s later 4:01.
        #expect(StatusBarPresentation.make(session: session, status: running, fetchedAt: fetchedAt, now: fetchedAt.addingTimeInterval(59)) == StatusBarPresentation(symbolName: "play.circle.fill", title: "4:00"))
        #expect(StatusBarPresentation.make(session: session, status: running, fetchedAt: fetchedAt, now: fetchedAt.addingTimeInterval(60)) == StatusBarPresentation(symbolName: "play.circle.fill", title: "4:01"))
    }

    @Test func pausedKeepsWorkTimeFrozen() throws {
        let paused = try Fixture.decode(TimeClockStatus.self, from: "status-paused")
        let presentation = StatusBarPresentation.make(session: .active(.apiToken), status: paused, fetchedAt: fetchedAt, now: fetchedAt.addingTimeInterval(3600))
        #expect(presentation == StatusBarPresentation(symbolName: "pause.circle.fill", title: "4:00"))
    }

    @Test func waitingShowsTheBadgeAndZeroTime() throws {
        let waiting = try Fixture.decode(TimeClockStatus.self, from: "status-waiting")
        let presentation = StatusBarPresentation.make(session: .active(.apiToken), status: waiting, fetchedAt: fetchedAt, now: fetchedAt.addingTimeInterval(500))
        #expect(presentation == StatusBarPresentation(symbolName: "clock.badge", title: "0:00"))
    }
}
