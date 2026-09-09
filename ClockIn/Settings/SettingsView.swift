import SwiftUI

/// FR-P1 and FR-P6: three tabs and the keychain note in the footer.
struct SettingsView: View {
    let store: ClockStore
    let preferences: Preferences
    let widget: WidgetPanelController
    let loginItem: LoginItemManager

    var body: some View {
        VStack(spacing: 0) {
            TabView {
                AccountTab(store: store)
                    .tabItem { Label("Konto", systemImage: "person.crop.circle") }
                GeneralTab(preferences: preferences, widget: widget, loginItem: loginItem)
                    .tabItem { Label("Allgemein", systemImage: "gearshape") }
                AboutTab()
                    .tabItem { Label("Info", systemImage: "info.circle") }
            }
            Text("Zugangsdaten liegen im macOS-Schlüsselbund und gehen ausschließlich an app.timebutler.com.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
        }
        .frame(width: 520, height: 380)
    }
}
