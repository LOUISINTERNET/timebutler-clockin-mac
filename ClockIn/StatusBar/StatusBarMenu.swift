import AppKit

/// The menu of the status item for left and right click (FR-M3, FR-M4, update entry FR-2 to
/// FR-4). As the menu's delegate it refills the items before every opening, so titles and
/// enabled states are current. Window-free, so its contents are tested.
@MainActor
final class StatusBarMenu: NSObject, NSMenuDelegate {
    private let store: ClockStore
    private let preferences: Preferences
    private let updateState: UpdateState
    private let toggleWidget: () -> Void
    private let raiseWidget: () -> Void
    private let openSettings: () -> Void
    private let checkForUpdates: () -> Void
    private let logger = Log.logger(.statusBar)

    init(
        store: ClockStore,
        preferences: Preferences,
        updateState: UpdateState,
        toggleWidget: @escaping () -> Void,
        raiseWidget: @escaping () -> Void,
        openSettings: @escaping () -> Void,
        checkForUpdates: @escaping () -> Void
    ) {
        self.store = store
        self.preferences = preferences
        self.updateState = updateState
        self.toggleWidget = toggleWidget
        self.raiseWidget = raiseWidget
        self.openSettings = openSettings
        self.checkForUpdates = checkForUpdates
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        menu.autoenablesItems = false
        menu.addItem(item(preferences.widgetVisible ? "Widget ausblenden" : "Widget einblenden", #selector(toggleWidgetItem), key: ""))
        let refresh = item("Jetzt aktualisieren", #selector(refreshNow), key: "")
        refresh.isEnabled = store.session.isActive
        menu.addItem(refresh)
        let update = item(updateState.menuTitle, #selector(checkForUpdatesItem), key: "")
        update.isEnabled = updateState.canCheckForUpdates
        menu.addItem(update)
        menu.addItem(.separator())
        menu.addItem(item("Einstellungen…", #selector(showSettings), key: ","))
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "\(AppIdentity.displayName) beenden", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quit.target = NSApp
        menu.addItem(quit)
    }

    /// FR-W9: without "Immer im Vordergrund" other windows may cover the widget; a click on
    /// the menu bar item brings it back to the front.
    func menuWillOpen(_ menu: NSMenu) {
        raiseWidget()
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

    @objc private func checkForUpdatesItem() {
        checkForUpdates()
    }
}
