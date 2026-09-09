import Foundation
import Testing

struct WorkSummaryLiveTests {
    private let fetchedAt = Date(timeIntervalSince1970: 1_000_000)
    private let summary = WorkSummary(commitmentMinutes: 480, workedMinutes: 192, remainingMinutes: 288, percentDone: 40, breakMinutes: 30)

    @Test func idleSummaryIsReturnedUnchanged() throws {
        let idle = try Fixture.decode(TimeClockStatus.self, from: "status-idle")
        #expect(summary.worked(including: idle, fetchedAt: fetchedAt, now: fetchedAt) == 192)
        #expect(summary.remaining(including: idle, fetchedAt: fetchedAt, now: fetchedAt) == 288)
        #expect(summary.percentDone(including: idle, fetchedAt: fetchedAt, now: fetchedAt) == 40)
        #expect(summary.worked(including: nil, fetchedAt: fetchedAt, now: fetchedAt) == 192)
    }

    @Test func runningSessionIsAddedToWorkedAndSubtractedFromRemaining() throws {
        let running = try Fixture.decode(TimeClockStatus.self, from: "status-running")
        let now = fetchedAt.addingTimeInterval(120)
        // 14400 s + 120 s = 242 minutes on top of the saved 192.
        #expect(summary.worked(including: running, fetchedAt: fetchedAt, now: now) == 434)
        #expect(summary.remaining(including: running, fetchedAt: fetchedAt, now: now) == 46)
        #expect(summary.percentDone(including: running, fetchedAt: fetchedAt, now: now) == 90)
    }

    @Test func remainingBecomesNegativeAfterCommitment() throws {
        let running = try Fixture.decode(TimeClockStatus.self, from: "status-running")
        let overtime = WorkSummary(commitmentMinutes: 200, workedMinutes: 0, remainingMinutes: 200, percentDone: 0, breakMinutes: 0)
        #expect(overtime.remaining(including: running, fetchedAt: fetchedAt, now: fetchedAt) == -40)
        #expect(overtime.percentDone(including: running, fetchedAt: fetchedAt, now: fetchedAt) == 100)
    }

    @Test func zeroCommitmentFallsBackToServerPercent() throws {
        let running = try Fixture.decode(TimeClockStatus.self, from: "status-running")
        let noCommitment = WorkSummary(commitmentMinutes: 0, workedMinutes: 10, remainingMinutes: 0, percentDone: 150, breakMinutes: 0)
        #expect(noCommitment.percentDone(including: running, fetchedAt: fetchedAt, now: fetchedAt) == 100)
    }
}
