import SwiftUI

/// FR-W8: the folded widget, one line with the state dot, the running time, since when it
/// runs (with the day's first clock-in in brackets), the actions of the state and the chevron.
struct WidgetCompactView: View {
    let store: ClockStore
    @Bindable var preferences: Preferences

    var body: some View {
        HStack(spacing: 6) {
            if let status = store.status, let fetchedAt = store.fetchedAt {
                Circle()
                    .fill(status.status.color)
                    .frame(width: 8, height: 8)
                VStack(alignment: .leading, spacing: 0) {
                    if status.status.isActive {
                        TimelineView(.periodic(from: .now, by: 1)) { context in
                            time(status: status, fetchedAt: fetchedAt, now: context.date)
                        }
                    } else {
                        time(status: status, fetchedAt: fetchedAt, now: fetchedAt)
                    }
                    Text(Self.since(status: status, firstStart: store.firstStartToday))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 4)
                actions(status: status)
            } else {
                Circle()
                    .fill(.gray)
                    .frame(width: 8, height: 8)
                Text(store.lastError ?? "lädt …")
                    .font(.subheadline)
                    .foregroundStyle(store.lastError == nil ? Color.secondary : Color.red)
                    .lineLimit(1)
                Spacer(minLength: 2)
            }
            WidgetCollapseButton(preferences: preferences)
        }
        .frame(height: WidgetLayout.foldedContentHeight)
    }

    private func time(status: TimeClockStatus, fetchedAt: Date, now: Date) -> some View {
        Text(WidgetTimeText.main(status: status, summary: store.summary, fetchedAt: fetchedAt, now: now))
            .font(.system(size: 20, weight: .semibold, design: .rounded))
            .monospacedDigit()
            .lineLimit(1)
            .fixedSize()
    }

    /// FR-C6 in miniature: pause or resume, then stop, each only when the state allows it.
    @ViewBuilder
    private func actions(status: TimeClockStatus) -> some View {
        HStack(spacing: 2) {
            if status.canPause {
                WidgetIconButton(symbol: "pause.circle.fill", tint: .orange, help: "Pause") { await store.perform(.pause) }
            }
            if status.canResume {
                WidgetIconButton(symbol: "play.circle.fill", tint: .green, help: "Weiter") { await store.perform(.resume) }
            }
            if status.canStop {
                WidgetIconButton(symbol: "stop.circle.fill", tint: .red, help: "Stopp") { await store.stop() }
            }
        }
        .disabled(store.isBusy)
    }

    /// "seit 17:27 (08:37)" while working, "Pause seit 17:35 (08:37)" while paused,
    /// "heute erfasst" while idle.
    static func since(status: TimeClockStatus, firstStart: String?) -> String {
        switch status.status {
        case .paused:
            if let pause = status.pauseTimestamp {
                return DayStart.sinceText(prefix: "Pause seit", currentStart: pause, firstStart: firstStart)
            }
            return "Pause"
        case .running, .waiting:
            if let start = status.startTimestamp {
                return DayStart.sinceText(prefix: "seit", currentStart: start, firstStart: firstStart)
            }
            return ""
        case .idle:
            return "heute erfasst"
        }
    }
}
