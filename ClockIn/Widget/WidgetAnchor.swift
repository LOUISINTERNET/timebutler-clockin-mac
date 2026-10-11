import AppKit

/// FR-W10: the corner of the widget that stays in place while its content grows or shrinks,
/// so unfolding, the start tile turning into the line and the break-regulation card all open
/// toward the middle of the screen. AppKit counts from the bottom left of the screen.
struct WidgetAnchor: Equatable {
    enum Horizontal: String {
        case left
        case right
    }

    enum Vertical: String {
        case top
        case bottom
    }

    let horizontal: Horizontal
    let vertical: Vertical

    /// The corner nearest to the edges of the visible screen area: right when the middle of
    /// the widget lies in the right half, bottom when it lies in the lower half, otherwise
    /// left and top as AppKit does by default.
    static func nearest(to frame: CGRect, in visibleFrame: CGRect) -> WidgetAnchor {
        WidgetAnchor(horizontal: frame.midX > visibleFrame.midX ? .right : .left, vertical: frame.midY < visibleFrame.midY ? .bottom : .top)
    }

    /// The point this anchor pins in `frame`.
    func corner(of frame: CGRect) -> CGPoint {
        CGPoint(x: horizontal == .right ? frame.maxX : frame.minX, y: vertical == .top ? frame.maxY : frame.minY)
    }

    /// The edge `NSWindow.setAnchorAttribute(_:for:)` keeps when constraints resize the window.
    var horizontalAttribute: NSLayoutConstraint.Attribute {
        horizontal == .right ? .right : .left
    }

    var verticalAttribute: NSLayoutConstraint.Attribute {
        vertical == .bottom ? .bottom : .top
    }
}
