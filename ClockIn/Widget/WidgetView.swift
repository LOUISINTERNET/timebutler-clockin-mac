import SwiftUI

/// Root of the floating widget (FR-W6): the signed-out notice, the break-regulation card,
/// the folded one-liner (FR-W8) or the clock face, on one Liquid Glass card of fixed width.
struct WidgetView: View {
    let store: ClockStore
    let preferences: Preferences
    let openSettings: () -> Void

    var body: some View {
        let layout = WidgetLayout.resolve(session: store.session, collapsed: preferences.widgetCollapsed, status: store.status, hasPendingBreakRegulation: store.pendingBreakRegulation != nil, lastError: store.lastError)
        content(for: layout)
            .padding(layout == .face || layout == .breakRegulation || layout == .signedOut ? 16 : 12)
            .frame(width: layout == .square ? nil : 260)
            .glassEffect(.regular, in: .rect(cornerRadius: 20))
    }

    @ViewBuilder
    private func content(for layout: WidgetLayout) -> some View {
        switch layout {
        case .signedOut:
            WidgetSignedOutView(message: store.session == .expired ? "Sitzung abgelaufen. Bitte neu anmelden." : "Nicht angemeldet.", openSettings: openSettings)
        case .breakRegulation:
            if let regulation = store.pendingBreakRegulation {
                BreakRegulationView(regulation: regulation, store: store)
            }
        case .square:
            WidgetSquareView(store: store, preferences: preferences)
        case .line:
            WidgetCompactView(store: store, preferences: preferences)
        case .face:
            clockFace
        }
    }

    @ViewBuilder
    private var clockFace: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let status = store.status, let fetchedAt = store.fetchedAt {
                WidgetHeaderView(status: status, firstStart: store.firstStartToday, preferences: preferences)
                WidgetClockView(status: status, summary: store.summary, fetchedAt: fetchedAt)
                if let summary = store.summary {
                    WidgetSummaryView(summary: summary, status: status, fetchedAt: fetchedAt)
                }
                WidgetActionsView(status: status, store: store)
            } else {
                HStack {
                    if store.lastError == nil {
                        Text("lädt …")
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    WidgetCollapseButton(preferences: preferences)
                }
            }
            WidgetStatusLineView(error: store.lastError, message: store.lastMessage)
        }
    }
}
