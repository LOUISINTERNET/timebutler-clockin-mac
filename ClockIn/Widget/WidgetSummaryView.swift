import SwiftUI

/// FR-C5: Soll, Ist and Rest (or Plus) with a progress bar in the state colour. The
/// running session is added on top of the saved entries and ticks with the clock.
struct WidgetSummaryView: View {
    let summary: WorkSummary
    let status: TimeClockStatus
    let fetchedAt: Date

    var body: some View {
        if status.status.isActive {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                rows(now: context.date)
            }
        } else {
            rows(now: fetchedAt)
        }
    }

    private func rows(now: Date) -> some View {
        let worked = summary.worked(including: status, fetchedAt: fetchedAt, now: now)
        let remaining = summary.remaining(including: status, fetchedAt: fetchedAt, now: now)
        let percent = summary.percentDone(including: status, fetchedAt: fetchedAt, now: now)
        return VStack(spacing: 6) {
            HStack {
                column("Soll", DurationFormatting.signedHoursMinutes(minutes: summary.commitmentMinutes))
                column("Ist", DurationFormatting.signedHoursMinutes(minutes: worked))
                column(remaining < 0 ? "Plus" : "Rest", DurationFormatting.signedHoursMinutes(minutes: abs(remaining)))
            }
            progressBar(percent: percent)
        }
    }

    /// Drawn by hand: a `ProgressView` renders grey in the never-key widget panel (D3).
    private func progressBar(percent: Int) -> some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.primary.opacity(0.12))
                Capsule()
                    .fill(status.status.color)
                    .frame(width: geometry.size.width * Double(percent) / 100)
            }
        }
        .frame(height: 6)
    }

    private func column(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.body.monospacedDigit())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
