import SwiftUI

/// Root of the floating widget (FR-W6): the signed-out notice, the break-regulation card,
/// the folded one-liner (FR-W8) or the clock face, on one Liquid Glass card of fixed width.
struct WidgetView: View {
    let store: ClockStore
    let preferences: Preferences
    let openSettings: () -> Void

    var body: some View {
        content
            .padding(isCompact ? 12 : 16)
            .frame(width: 260)
            .glassEffect(.regular, in: .rect(cornerRadius: 20))
    }

    /// Folded only while signed in and no break-regulation card needs its buttons.
    private var isCompact: Bool {
        preferences.widgetCollapsed && store.session.isActive && store.pendingBreakRegulation == nil
    }

    @ViewBuilder
    private var content: some View {
        switch store.session {
        case .notConfigured:
            WidgetSignedOutView(message: "Nicht angemeldet.", openSettings: openSettings)
        case .expired:
            WidgetSignedOutView(message: "Sitzung abgelaufen. Bitte neu anmelden.", openSettings: openSettings)
        case .active:
            if let regulation = store.pendingBreakRegulation {
                BreakRegulationView(regulation: regulation, store: store)
            } else if preferences.widgetCollapsed {
                WidgetCompactView(status: store.status, summary: store.summary, fetchedAt: store.fetchedAt, lastError: store.lastError, preferences: preferences)
            } else {
                clockFace
            }
        }
    }

    @ViewBuilder
    private var clockFace: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let status = store.status, let fetchedAt = store.fetchedAt {
                WidgetHeaderView(status: status, preferences: preferences)
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
