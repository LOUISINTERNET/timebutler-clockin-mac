import Foundation

/// Timebutler's work summary counts saved entries only. While a session is active the
/// running session has to be added so "Ist" and "Rest" reflect the current moment.
extension WorkSummary {
    func worked(including status: TimeClockStatus?, fetchedAt: Date, now: Date) -> Int {
        workedMinutes + liveWorkMinutes(status: status, fetchedAt: fetchedAt, now: now)
    }

    /// Computed from commitment and worked time, not from the server's `remainingMinutes`:
    /// Timebutler clamps that value at zero, which would hide overtime ("Plus", FR-C5).
    func remaining(including status: TimeClockStatus?, fetchedAt: Date, now: Date) -> Int {
        commitmentMinutes - worked(including: status, fetchedAt: fetchedAt, now: now)
    }

    /// Whole percent of the daily commitment, clamped to 0...100 for the progress bar.
    func percentDone(including status: TimeClockStatus?, fetchedAt: Date, now: Date) -> Int {
        guard commitmentMinutes > 0 else {
            return min(max(percentDone, 0), 100)
        }
        let workedNow = worked(including: status, fetchedAt: fetchedAt, now: now)
        let percent = Int((Double(workedNow) / Double(commitmentMinutes) * 100).rounded())
        return min(max(percent, 0), 100)
    }

    private func liveWorkMinutes(status: TimeClockStatus?, fetchedAt: Date, now: Date) -> Int {
        guard let status, status.status.isActive else {
            return 0
        }
        return LiveClock.workSeconds(status: status, fetchedAt: fetchedAt, now: now) / 60
    }
}
