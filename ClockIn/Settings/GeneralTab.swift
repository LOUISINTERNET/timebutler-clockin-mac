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
                    Button {
                        loginItem.openSystemSettings()
                    } label: {
                        Label("Anmeldeobjekte in den Systemeinstellungen öffnen", systemImage: "power")
                    }
                }
                if let error = loginItem.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            } header: {
                Text("Start")
            } footer: {
                if loginItem.requiresApproval {
                    Text("macOS wartet auf deine Freigabe in den Systemeinstellungen.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Section {
                Toggle("Widget anzeigen", isOn: widgetVisible)
                Toggle("Immer im Vordergrund", isOn: $preferences.widgetAlwaysOnTop)
                Toggle("Auf allen Schreibtischen anzeigen", isOn: $preferences.widgetOnAllSpaces)
                Button {
                    widget.resetPosition()
                } label: {
                    Label("Widget-Position zurücksetzen", systemImage: "arrow.counterclockwise")
                }
            } header: {
                Text("Widget")
            } footer: {
                Text("Ohne \"Immer im Vordergrund\" dürfen andere Fenster das Widget verdecken; ein Klick auf das Menüleisten-Symbol holt es nach vorn. Die Position bleibt über Neustarts erhalten.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
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
