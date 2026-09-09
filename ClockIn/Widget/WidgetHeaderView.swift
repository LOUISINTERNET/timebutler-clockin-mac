import SwiftUI

/// FR-C2: coloured dot, state label, "seit HH:MM" while a session is active, and the
/// chevron that folds the widget (FR-W8).
struct WidgetHeaderView: View {
    let status: TimeClockStatus
    let preferences: Preferences

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(status.status.color)
                .frame(width: 8, height: 8)
            Text(status.status.germanLabel)
                .font(.headline)
            Spacer()
            if status.status.isActive, let start = status.startTimestamp {
                Text("seit \(DurationFormatting.clockTime(millisecondsSince1970: start))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            WidgetCollapseButton(preferences: preferences)
        }
    }
}
