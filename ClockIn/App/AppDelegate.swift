import AppKit

@main
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let logger = Log.logger(.lifecycle)
    private var dependencies: AppDependencies?
    private var widget: WidgetPanelController?
    private var statusBar: StatusBarController?
    private var settings: SettingsWindowController?
    private var updater: Updater?
    private let loginItem = LoginItemManager()

    /// AppKit's default `NSApplicationDelegate.main()` only calls `NSApplicationMain`, which
    /// wires the delegate through a main nib. This app has no nib, so the delegate is set here.
    static func main() {
        let application = NSApplication.shared
        let delegate = AppDelegate()
        application.delegate = delegate
        application.run()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        guard let dependencies = buildDependencies() else {
            NSApp.terminate(nil)
            return
        }
        self.dependencies = dependencies
        let openSettings: () -> Void = { [weak self] in
            self?.settings?.show()
        }
        let updateState = UpdateState()
        let updater = Updater(updateState: updateState)
        self.updater = updater
        let checkForUpdates: () -> Void = { updater.checkForUpdates() }
        let widget = WidgetPanelController(store: dependencies.store, preferences: dependencies.preferences, openSettings: openSettings)
        let menu = StatusBarMenu(
            store: dependencies.store,
            preferences: dependencies.preferences,
            updateState: updateState,
            toggleWidget: { widget.toggle() },
            raiseWidget: { widget.raiseIfVisible() },
            openSettings: openSettings,
            checkForUpdates: checkForUpdates
        )
        statusBar = StatusBarController(store: dependencies.store, menu: menu)
        settings = SettingsWindowController(
            store: dependencies.store,
            preferences: dependencies.preferences,
            widget: widget,
            loginItem: loginItem,
            updateState: updateState,
            checkForUpdates: checkForUpdates
        )
        self.widget = widget
        MainMenu.install(settingsTarget: self, settingsAction: #selector(showSettings))
        loginItem.reregisterIfLost(wanted: dependencies.preferences.launchAtLogin)
        Task {
            await dependencies.store.start()
        }
        dependencies.scheduler.start()
        if dependencies.preferences.widgetVisible {
            widget.show()
        }
        logger.notice("\(AppIdentity.displayName, privacy: .public) launched")
    }

    @objc private func showSettings() {
        settings?.show()
    }

    func applicationWillTerminate(_ notification: Notification) {
        dependencies?.scheduler.stop()
        dependencies?.store.stopObserving()
        logger.notice("\(AppIdentity.displayName, privacy: .public) terminating")
    }

    /// EC-4: a keychain that refuses to answer, or an unreadable record, is reported instead
    /// of being worked around. The user may delete the record and start signed out.
    private func buildDependencies() -> AppDependencies? {
        do {
            return try AppDependencies()
        } catch {
            logger.error("Launch failed, credentials could not be read: \(String(describing: error), privacy: .public)")
            guard askToResetCredentials(after: error) else {
                return nil
            }
        }
        do {
            try KeychainCredentialStore().delete()
            return try AppDependencies()
        } catch {
            logger.error("Credential reset failed: \(String(describing: error), privacy: .public)")
            return nil
        }
    }

    private func askToResetCredentials(after error: any Error) -> Bool {
        let alert = NSAlert()
        alert.messageText = "\(AppIdentity.displayName) kann die Zugangsdaten nicht aus dem Schlüsselbund lesen."
        alert.informativeText = "\((error as? KeychainError)?.message ?? String(describing: error))\n\nDu kannst den Eintrag löschen und dich danach neu anmelden."
        alert.addButton(withTitle: "Zugangsdaten löschen")
        alert.addButton(withTitle: "Beenden")
        NSApp.activate()
        return alert.runModal() == .alertFirstButtonReturn
    }
}
