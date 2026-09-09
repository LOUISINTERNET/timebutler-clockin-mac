import AppKit
import Observation
import SwiftUI

/// Owns the widget panel: position, visibility and Space behaviour (FR-W2 to FR-W5, EC-7).
@MainActor
final class WidgetPanelController {
    private static let autosaveName = "WidgetPanel"
    private static let screenInset: CGFloat = 20

    private let panel = WidgetPanel()
    private let preferences: Preferences
    private let logger = Log.logger(.widget)

    init(store: ClockStore, preferences: Preferences, openSettings: @escaping () -> Void) {
        self.preferences = preferences
        // A hosting controller, not a bare hosting view: `.preferredContentSize` only drives
        // the window through the content view controller. AppKit then keeps the top edge in
        // place when the content height changes with the clock state.
        let controller = NSHostingController(rootView: WidgetView(store: store, openSettings: openSettings))
        controller.sizingOptions = [.preferredContentSize]
        panel.contentViewController = controller
        panel.setContentSize(controller.view.fittingSize)
        if !panel.setFrameUsingName(Self.autosaveName) {
            resetPosition()
        }
        panel.setFrameAutosaveName(Self.autosaveName)
        applyCollectionBehavior()
        observeCollectionPreference()
    }

    var isVisible: Bool {
        panel.isVisible
    }

    func show() {
        if !preferences.widgetVisible {
            preferences.widgetVisible = true
        }
        ensureOnScreen()
        panel.orderFrontRegardless()
        logger.notice("Widget shown")
    }

    func hide() {
        if preferences.widgetVisible {
            preferences.widgetVisible = false
        }
        panel.orderOut(nil)
        logger.notice("Widget hidden")
    }

    /// FR-M3: bring the widget above every other window without activating the app.
    func raise() {
        panel.orderFrontRegardless()
    }

    func toggle() {
        if panel.isVisible {
            hide()
        } else {
            show()
        }
    }

    /// FR-W3: top right of the main screen, 20 points from the edge and the menu bar.
    func resetPosition() {
        guard let screen = NSScreen.main else {
            logger.error("No main screen, widget position left unchanged")
            return
        }
        let visible = screen.visibleFrame
        let size = panel.frame.size
        panel.setFrameOrigin(NSPoint(x: visible.maxX - size.width - Self.screenInset, y: visible.maxY - size.height - Self.screenInset))
        logger.notice("Widget position reset to the top right corner of \(screen.localizedName, privacy: .public), frame \(String(describing: self.panel.frame), privacy: .public)")
    }

    /// EC-7: a frame that intersects no screen (display removed) goes back to the default.
    private func ensureOnScreen() {
        let onScreen = NSScreen.screens.contains { $0.visibleFrame.intersects(panel.frame) }
        if !onScreen {
            resetPosition()
        }
    }

    /// FR-W4: every Space and full-screen apps, or only the active Space.
    private func applyCollectionBehavior() {
        panel.collectionBehavior = preferences.widgetOnAllSpaces ? [.canJoinAllSpaces, .fullScreenAuxiliary] : [.moveToActiveSpace]
    }

    private func observeCollectionPreference() {
        withObservationTracking {
            _ = preferences.widgetOnAllSpaces
        } onChange: { [weak self] in
            Task { @MainActor in
                guard let self else {
                    return
                }
                self.applyCollectionBehavior()
                self.observeCollectionPreference()
            }
        }
    }
}
