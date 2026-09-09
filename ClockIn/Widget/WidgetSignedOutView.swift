import SwiftUI

/// FR-S6 and FR-S7: no credentials or an expired session. The only way to the settings
/// window from the widget (FR-W7).
struct WidgetSignedOutView: View {
    let message: String
    let openSettings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(AppIdentity.displayName, systemImage: StatusBarPresentation.signedOutSymbol)
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            // Not .accentColor: an inactive window resolves that to grey (D3, the panel is never key).
            WidgetButton(title: "Einstellungen öffnen", symbol: "gearshape", tint: .blue, prominent: true) { openSettings() }
        }
    }
}
