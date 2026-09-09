import SwiftUI

/// FR-C3 and FR-C4: the big time and the line below it, ticking locally once per second
/// while a session is active.
struct WidgetClockView: View {
    let status: TimeClockStatus
    let summary: WorkSummary?
    let fetchedAt: Date

    var body: some View {
        if status.status.isActive {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                face(now: context.date)
            }
        } else {
            face(now: fetchedAt)
        }
    }

    private func face(now: Date) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(mainTime(now: now))
                .font(.system(size: 40, weight: .semibold, design: .rounded))
                .monospacedDigit()
            Text(subline(now: now))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private func mainTime(now: Date) -> String {
        switch status.status {
        case .running, .waiting:
            DurationFormatting.hoursMinutesSeconds(seconds: LiveClock.workSeconds(status: status, fetchedAt: fetchedAt, now: now))
        case .paused:
            DurationFormatting.hoursMinutesSeconds(seconds: LiveClock.breakSeconds(status: status, fetchedAt: fetchedAt, now: now))
        case .idle:
            summary.map { DurationFormatting.signedHoursMinutes(minutes: $0.workedMinutes) } ?? "–"
        }
    }

    private func subline(now: Date) -> String {
        if status.status == .paused {
            return "Pause läuft · \(DurationFormatting.hoursMinutesSeconds(seconds: LiveClock.breakSeconds(status: status, fetchedAt: fetchedAt, now: now)))"
        }
        if status.accumulatedBreakSeconds > 0 {
            return "Pause \(DurationFormatting.hoursMinutes(seconds: status.accumulatedBreakSeconds))"
        }
        return status.status.isActive ? "keine Pause" : "heute erfasst"
    }
}
