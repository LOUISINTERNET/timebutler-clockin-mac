import AppKit
import SwiftUI

/// The settings window (design decision D14). One instance lives as long as the app;
/// closing hides it, showing activates the accessory app first.
@MainActor
final class SettingsWindowController {
    private let window: NSWindow
    private let logger = Log.logger(.settings)

    init(store: ClockStore, preferences: Preferences, widget: WidgetPanelController, loginItem: LoginItemManager) {
        let hosting = NSHostingController(rootView: SettingsView(store: store, preferences: preferences, widget: widget, loginItem: loginItem))
        window = NSWindow(contentViewController: hosting)
        window.title = AppIdentity.displayName
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.setContentSize(NSSize(width: 520, height: 380))
        window.center()
    }

    /// FR-P1: accessory apps have to activate explicitly, otherwise the window stays behind.
    func show() {
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
        logger.notice("Settings window shown")
    }
}
