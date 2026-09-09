import SwiftUI

/// FR-C2: coloured dot, state label, "seit HH:MM (first start of the day)" while a session
/// is active, and the chevron that folds the widget (FR-W8).
struct WidgetHeaderView: View {
    let status: TimeClockStatus
    let firstStart: String?
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
                Text(DayStart.sinceText(prefix: "seit", currentStart: start, firstStart: firstStart))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            WidgetCollapseButton(preferences: preferences)
        }
    }
}
