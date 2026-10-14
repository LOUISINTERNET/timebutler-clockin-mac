import AppKit
import Observation
import SwiftUI

/// Owns the widget panel: position, visibility and Space behaviour (FR-W2 to FR-W5, FR-W10, EC-7).
@MainActor
final class WidgetPanelController {
    private static let screenInset: CGFloat = 20

    private let panel = WidgetPanel()
    private let preferences: Preferences
    private let logger = Log.logger(.widget)
    /// Nil only while no screen was available to place the widget on.
    private var position: WidgetPosition?
    private var moveObserver: (any NSObjectProtocol)?

    init(store: ClockStore, preferences: Preferences, openSettings: @escaping () -> Void) {
        self.preferences = preferences
        // A hosting controller, not a bare hosting view: `.preferredContentSize` only drives
        // the window through the content view controller. AppKit then keeps the pinned
        // corner (FR-W10) in place when the content size changes with the clock state.
        let controller = NSHostingController(rootView: WidgetView(store: store, preferences: preferences, openSettings: openSettings))
        controller.sizingOptions = [.preferredContentSize]
        panel.contentViewController = controller
        panel.setContentSize(controller.view.fittingSize)
        // No frame autosave: AppKit restores the saved origin with the current size, and a
        // frame that then no longer fits its screen lands on `NSScreen.main`, often another
        // display. The pinned corner is independent of the size.
        if let saved = preferences.widgetPosition {
            place(at: saved)
            logger.notice("Widget restored at \(String(describing: self.panel.frame), privacy: .public)")
        } else {
            resetPosition()
        }
        applyWindowBehavior()
        observeWindowPreferences()
        observeMoves()
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

    /// FR-M3: brings a visible widget above every other window without activating the app;
    /// a hidden widget stays hidden.
    func raiseIfVisible() {
        guard panel.isVisible else {
            return
        }
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
        place(at: WidgetPosition(anchor: WidgetAnchor(horizontal: .right, vertical: .top), corner: CGPoint(x: visible.maxX - Self.screenInset, y: visible.maxY - Self.screenInset)))
        logger.notice("Widget position reset to the top right corner of \(screen.localizedName, privacy: .public), frame \(String(describing: self.panel.frame), privacy: .public)")
    }

    private func place(at newPosition: WidgetPosition) {
        pin(newPosition)
        panel.setFrame(newPosition.frame(for: panel.frame.size), display: true)
    }

    /// FR-W10: AppKit keeps this corner when constraints resize the window. FR-W2: it is
    /// saved for the next launch.
    private func pin(_ newPosition: WidgetPosition) {
        if newPosition.anchor != position?.anchor {
            logger.notice("Widget anchored \(newPosition.anchor.horizontal.rawValue, privacy: .public) \(newPosition.anchor.vertical.rawValue, privacy: .public) at \(String(describing: newPosition.corner), privacy: .public)")
        }
        position = newPosition
        panel.setAnchorAttribute(newPosition.anchor.horizontalAttribute, for: .horizontal)
        panel.setAnchorAttribute(newPosition.anchor.verticalAttribute, for: .vertical)
        preferences.widgetPosition = newPosition
    }

    /// A drag or a display change moves the pinned corner; only then the position follows.
    /// The content growing or shrinking moves the window as well but keeps the corner, and
    /// measuring again there would let a widget near the middle of the screen wander with
    /// every fold.
    private func observeMoves() {
        moveObserver = NotificationCenter.default.addObserver(forName: NSWindow.didMoveNotification, object: panel, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.panelDidMove()
            }
        }
    }

    private func panelDidMove() {
        if let position, position.isKept(by: panel.frame) {
            return
        }
        guard let screen = panel.screen else {
            logger.error("Widget frame \(String(describing: self.panel.frame), privacy: .public) is on no screen, position left unchanged")
            return
        }
        pin(WidgetPosition.nearest(to: panel.frame, in: screen.visibleFrame))
    }

    /// EC-7: a widget on no screen (display removed) goes back to the default. One that sticks
    /// out of the screen it is mostly on (resolution or arrangement changed while the app was
    /// not running) moves back inside.
    private func ensureOnScreen() {
        let frame = panel.frame
        let overlaps = NSScreen.screens.map { screen in
            let overlap = screen.visibleFrame.intersection(frame)
            return (screen: screen, area: overlap.isNull ? 0 : overlap.width * overlap.height)
        }
        guard let best = overlaps.max(by: { $0.area < $1.area }), best.area > 0 else {
            resetPosition()
            return
        }
        let visible = best.screen.visibleFrame
        guard !visible.contains(frame), let position else {
            return
        }
        place(at: position.moved(into: visible, size: frame.size))
        logger.notice("Widget stuck out of \(best.screen.localizedName, privacy: .public), moved inside to \(String(describing: self.panel.frame), privacy: .public)")
    }

    /// FR-W4: every Space and full-screen apps, or only the active Space. FR-W9: floating
    /// above everything, or a normal window that other apps may cover.
    private func applyWindowBehavior() {
        panel.collectionBehavior = preferences.widgetOnAllSpaces ? [.canJoinAllSpaces, .fullScreenAuxiliary] : [.moveToActiveSpace]
        panel.level = preferences.widgetAlwaysOnTop ? .floating : .normal
        if panel.isVisible {
            panel.orderFrontRegardless()
        }
    }

    private func observeWindowPreferences() {
        withObservationTracking {
            _ = preferences.widgetOnAllSpaces
            _ = preferences.widgetAlwaysOnTop
        } onChange: { [weak self] in
            Task { @MainActor in
                guard let self else {
                    return
                }
                self.applyWindowBehavior()
                self.observeWindowPreferences()
            }
        }
    }
}
