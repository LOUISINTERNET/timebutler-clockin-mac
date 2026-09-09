import SwiftUI

/// FR-C9: the card Timebutler's `confirmationRequired` answer opens instead of saving.
struct BreakRegulationView: View {
    static let fallbackText = "Der Zeiteintrag verletzt die Pausenregelung."

    let regulation: BreakRegulation
    let store: ClockStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Pausenregelung", systemImage: "exclamationmark.triangle.fill")
                .font(.headline)
                .foregroundStyle(.orange)
            Text(regulation.detailText.isEmpty ? Self.fallbackText : regulation.detailText)
                .font(.subheadline)
            if !regulation.hasNoRemedy, let minutes = regulation.resultingWorkMinutes {
                Text("Ergebnis: \(DurationFormatting.signedHoursMinutes(minutes: minutes))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 8) {
                if regulation.hasNoRemedy {
                    WidgetButton(title: "Verwerfen", symbol: "trash", tint: .red, prominent: false) { await store.perform(.cancel) }
                } else {
                    WidgetButton(title: "Korrektur", symbol: "checkmark", tint: .green, prominent: true) { await store.stop(decision: .apply) }
                }
                if !regulation.obligatory {
                    WidgetButton(title: "Trotzdem", symbol: "exclamationmark", tint: .orange, prominent: false) { await store.stop(decision: .ignore) }
                }
                WidgetButton(title: "Zurück", tint: .secondary, prominent: false) { store.dismissBreakRegulation() }
                if store.isBusy {
                    ProgressView()
                        .controlSize(.small)
                }
            }
            .disabled(store.isBusy)
            WidgetStatusLineView(error: store.lastError, message: nil)
        }
    }
}
