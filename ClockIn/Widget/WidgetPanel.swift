import AppKit

/// The borderless, non-activating floating window of the widget (design decision D3).
/// Clicking a button inside it never switches the active app.
final class WidgetPanel: NSPanel {
    init() {
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView], backing: .buffered, defer: false)
        level = .floating
        isMovableByWindowBackground = true
        hidesOnDeactivate = false
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        isReleasedWhenClosed = false
        animationBehavior = .none
    }

    override var canBecomeKey: Bool {
        false
    }

    override var canBecomeMain: Bool {
        false
    }

    /// FR-W2: dragging works on every spot without a control, SwiftUI areas included. A
    /// click also brings the panel to the front, which matters when it is not floating (FR-W9).
    override func mouseDown(with event: NSEvent) {
        orderFrontRegardless()
        performDrag(with: event)
    }
}
