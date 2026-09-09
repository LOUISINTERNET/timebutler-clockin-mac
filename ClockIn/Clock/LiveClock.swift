import Foundation

/// Extrapolates the server-reported clock values between two status fetches so the
/// widget can tick every second without asking Timebutler every second.
enum LiveClock {
    /// Net work seconds: the server value plus the seconds elapsed since the fetch,
    /// but only while the clock is running.
    static func workSeconds(status: TimeClockStatus, fetchedAt: Date, now: Date) -> Int {
        guard status.status == .running else {
            return status.workTimeElapsedSeconds
        }
        return status.workTimeElapsedSeconds + elapsedSeconds(fetchedAt: fetchedAt, now: now)
    }

    /// Seconds of the current break: the server value plus the seconds elapsed since the
    /// fetch, but only while the clock is paused.
    static func breakSeconds(status: TimeClockStatus, fetchedAt: Date, now: Date) -> Int {
        guard status.status == .paused else {
            return status.breakElapsedSeconds
        }
        return status.breakElapsedSeconds + elapsedSeconds(fetchedAt: fetchedAt, now: now)
    }

    private static func elapsedSeconds(fetchedAt: Date, now: Date) -> Int {
        max(0, Int(now.timeIntervalSince(fetchedAt)))
    }
}
