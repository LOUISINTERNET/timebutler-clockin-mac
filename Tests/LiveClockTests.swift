import Foundation
import Testing

struct LiveClockTests {
    private let fetchedAt = Date(timeIntervalSince1970: 1_000_000)

    @Test func workSecondsGrowWhileRunning() throws {
        let status = try Fixture.decode(TimeClockStatus.self, from: "status-running")
        let later = fetchedAt.addingTimeInterval(90)
        #expect(LiveClock.workSeconds(status: status, fetchedAt: fetchedAt, now: later) == 14_490)
        #expect(LiveClock.breakSeconds(status: status, fetchedAt: fetchedAt, now: later) == 0)
    }

    @Test func breakSecondsGrowWhilePaused() throws {
        let status = try Fixture.decode(TimeClockStatus.self, from: "status-paused")
        let later = fetchedAt.addingTimeInterval(45)
        #expect(LiveClock.workSeconds(status: status, fetchedAt: fetchedAt, now: later) == 14_400)
        #expect(LiveClock.breakSeconds(status: status, fetchedAt: fetchedAt, now: later) == 645)
    }

    @Test func nothingGrowsWhileIdleOrWaiting() throws {
        let later = fetchedAt.addingTimeInterval(3600)
        let idle = try Fixture.decode(TimeClockStatus.self, from: "status-idle")
        #expect(LiveClock.workSeconds(status: idle, fetchedAt: fetchedAt, now: later) == 0)
        let waiting = try Fixture.decode(TimeClockStatus.self, from: "status-waiting")
        #expect(LiveClock.workSeconds(status: waiting, fetchedAt: fetchedAt, now: later) == 0)
        #expect(LiveClock.breakSeconds(status: waiting, fetchedAt: fetchedAt, now: later) == 0)
    }

    @Test func clockGoingBackwardsDoesNotShrinkValues() throws {
        let status = try Fixture.decode(TimeClockStatus.self, from: "status-running")
        let earlier = fetchedAt.addingTimeInterval(-120)
        #expect(LiveClock.workSeconds(status: status, fetchedAt: fetchedAt, now: earlier) == 14_400)
    }
}
