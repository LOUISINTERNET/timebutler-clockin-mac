import AppKit

/// The right-click menu of the status item (FR-M4). Window-free, so its contents are tested.
@MainActor
final class StatusBarMenu: NSObject {
    private let store: ClockStore
    private let preferences: Preferences
    private let toggleWidget: () -> Void
    private let openSettings: () -> Void
    private let logger = Log.logger(.statusBar)

    init(store: ClockStore, preferences: Preferences, toggleWidget: @escaping () -> Void, openSettings: @escaping () -> Void) {
        self.store = store
        self.preferences = preferences
        self.toggleWidget = toggleWidget
        self.openSettings = openSettings
    }

    func build() -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.addItem(item(preferences.widgetVisible ? "Widget ausblenden" : "Widget einblenden", #selector(toggleWidgetItem), key: ""))
        let refresh = item("Jetzt aktualisieren", #selector(refreshNow), key: "")
        refresh.isEnabled = store.session.isActive
        menu.addItem(refresh)
        menu.addItem(.separator())
        menu.addItem(item("Einstellungen…", #selector(showSettings), key: ","))
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "\(AppIdentity.displayName) beenden", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quit.target = NSApp
        menu.addItem(quit)
        return menu
    }

    private func item(_ title: String, _ action: Selector, key: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        return item
    }

    @objc private func toggleWidgetItem() {
        toggleWidget()
    }

    @objc private func refreshNow() {
        logger.notice("Manual refresh from the menu")
        Task {
            await store.refresh()
        }
    }

    @objc private func showSettings() {
        openSettings()
    }
}
