import SwiftUI

/// FR-P4: launch at login and the widget switches.
struct GeneralTab: View {
    @Bindable var preferences: Preferences
    let widget: WidgetPanelController
    let loginItem: LoginItemManager

    var body: some View {
        Form {
            Section {
                Toggle("Beim Anmelden starten", isOn: launchAtLogin)
                if loginItem.requiresApproval {
                    HStack {
                        Text("macOS wartet auf deine Freigabe in den Systemeinstellungen.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Button("Systemeinstellungen öffnen") {
                            loginItem.openSystemSettings()
                        }
                    }
                }
                if let error = loginItem.errorMessage {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
            Section {
                Toggle("Widget anzeigen", isOn: widgetVisible)
                Toggle("Auf allen Schreibtischen anzeigen", isOn: $preferences.widgetOnAllSpaces)
                Button("Widget-Position zurücksetzen") {
                    widget.resetPosition()
                }
            }
        }
        .formStyle(.grouped)
        .onAppear {
            loginItem.refresh()
        }
    }

    private var launchAtLogin: Binding<Bool> {
        Binding(
            get: { loginItem.isEnabled || loginItem.requiresApproval },
            set: { wanted in
                preferences.launchAtLogin = wanted
                loginItem.setEnabled(wanted)
            }
        )
    }

    private var widgetVisible: Binding<Bool> {
        Binding(
            get: { preferences.widgetVisible },
            set: { visible in
                if visible {
                    widget.show()
                } else {
                    widget.hide()
                }
            }
        )
    }
}
