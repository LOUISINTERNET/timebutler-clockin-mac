import AppKit
import SwiftUI

/// The settings window (design decision D14): an `NSTabViewController` in toolbar style,
/// which puts the three tabs into the title bar like every native preferences window.
/// One instance lives as long as the app; closing hides it.
@MainActor
final class SettingsWindowController {
    private let window: NSWindow
    private let logger = Log.logger(.settings)

    init(store: ClockStore, preferences: Preferences, widget: WidgetPanelController, loginItem: LoginItemManager) {
        let tabs = NSTabViewController()
        tabs.tabStyle = .toolbar
        tabs.addTabViewItem(Self.tab("Konto", symbol: "person.crop.circle") { AccountTab(store: store) })
        tabs.addTabViewItem(Self.tab("Allgemein", symbol: "gearshape") { GeneralTab(preferences: preferences, widget: widget, loginItem: loginItem) })
        tabs.addTabViewItem(Self.tab("Info", symbol: "info.circle") { AboutTab() })
        window = NSWindow(contentViewController: tabs)
        window.styleMask = [.titled, .closable]
        window.toolbarStyle = .preference
        window.isReleasedWhenClosed = false
        window.setContentSize(SettingsTabContainer<EmptyView>.size)
        window.center()
    }

    /// FR-P1: accessory apps have to activate explicitly, otherwise the window stays behind.
    func show() {
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
        logger.notice("Settings window shown")
    }

    /// The controller title becomes the window title (FR-P1); the preferred size keeps
    /// the window at the tab's fixed frame instead of the tab view's own default.
    private static func tab(_ label: String, symbol: String, @ViewBuilder content: () -> some View) -> NSTabViewItem {
        let hosting = NSHostingController(rootView: SettingsTabContainer(content: content))
        hosting.title = label
        hosting.preferredContentSize = SettingsTabContainer<EmptyView>.size
        let item = NSTabViewItem(viewController: hosting)
        item.label = label
        item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: label)
        return item
    }
}
