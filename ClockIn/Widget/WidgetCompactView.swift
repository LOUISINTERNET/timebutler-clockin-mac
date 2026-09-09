import SwiftUI

/// FR-W8: the folded widget, one line with the state dot, the running time and since when
/// it runs: the clock-in time while working, the start of the break while paused.
struct WidgetCompactView: View {
    let status: TimeClockStatus?
    let summary: WorkSummary?
    let fetchedAt: Date?
    let lastError: String?
    @Bindable var preferences: Preferences

    var body: some View {
        HStack(spacing: 8) {
            if let status, let fetchedAt {
                Circle()
                    .fill(status.status.color)
                    .frame(width: 8, height: 8)
                if status.status.isActive {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        time(status: status, fetchedAt: fetchedAt, now: context.date)
                    }
                } else {
                    time(status: status, fetchedAt: fetchedAt, now: fetchedAt)
                }
                Text(Self.since(status: status))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            } else {
                Circle()
                    .fill(.gray)
                    .frame(width: 8, height: 8)
                Text(lastError ?? "lädt …")
                    .font(.subheadline)
                    .foregroundStyle(lastError == nil ? Color.secondary : Color.red)
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            WidgetCollapseButton(preferences: preferences)
        }
    }

    private func time(status: TimeClockStatus, fetchedAt: Date, now: Date) -> some View {
        Text(WidgetTimeText.main(status: status, summary: summary, fetchedAt: fetchedAt, now: now))
            .font(.system(size: 20, weight: .semibold, design: .rounded))
            .monospacedDigit()
    }

    /// "seit 08:37" while working, "Pause seit 12:05" while paused, "heute erfasst" while idle.
    static func since(status: TimeClockStatus) -> String {
        switch status.status {
        case .paused:
            if let pause = status.pauseTimestamp {
                return "Pause seit \(DurationFormatting.clockTime(millisecondsSince1970: pause))"
            }
            return "Pause"
        case .running, .waiting:
            if let start = status.startTimestamp {
                return "seit \(DurationFormatting.clockTime(millisecondsSince1970: start))"
            }
            return ""
        case .idle:
            return "heute erfasst"
        }
    }
}
