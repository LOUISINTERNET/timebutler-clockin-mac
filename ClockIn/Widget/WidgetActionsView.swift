import SwiftUI

/// FR-C6 and FR-C7: the buttons of the current state, disabled while a call runs.
struct WidgetActionsView: View {
    let status: TimeClockStatus
    let store: ClockStore

    var body: some View {
        if status.allActionsTerminalOnly {
            Text("Bedienung nur am Zeiterfassungsterminal möglich.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        } else {
            HStack(spacing: 8) {
                if status.canStart {
                    WidgetButton(title: "Start", symbol: "play.fill", tint: .green, prominent: true) { await store.perform(.start) }
                }
                if status.canPause {
                    WidgetButton(title: "Pause", symbol: "pause.fill", tint: .orange, prominent: false) { await store.perform(.pause) }
                }
                if status.canResume {
                    WidgetButton(title: "Weiter", symbol: "play.fill", tint: .green, prominent: true) { await store.perform(.resume) }
                }
                if status.canStop {
                    WidgetButton(title: "Stopp", symbol: "stop.fill", tint: .red, prominent: false) { await store.stop() }
                }
                if store.isBusy {
                    ProgressView()
                        .controlSize(.small)
                }
            }
            .disabled(store.isBusy)
        }
    }
}
