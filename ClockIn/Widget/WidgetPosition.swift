import CoreGraphics

/// FR-W2, FR-W10: where the widget sits, as its pinned corner in global screen coordinates.
/// The size is not part of it; it always follows the content.
struct WidgetPosition: Equatable {
    private static let horizontalKey = "horizontal"
    private static let verticalKey = "vertical"
    private static let xKey = "x"
    private static let yKey = "y"
    /// Moves smaller than this are rounding in the window frame, not a drag.
    private static let tolerance: CGFloat = 0.5

    let anchor: WidgetAnchor
    let corner: CGPoint

    init(anchor: WidgetAnchor, corner: CGPoint) {
        self.anchor = anchor
        self.corner = corner
    }

    /// Reads what `propertyList` wrote; nil when a key is missing or has the wrong type.
    init?(propertyList: [String: Any]) {
        guard let horizontal = (propertyList[Self.horizontalKey] as? String).flatMap(WidgetAnchor.Horizontal.init(rawValue:)),
              let vertical = (propertyList[Self.verticalKey] as? String).flatMap(WidgetAnchor.Vertical.init(rawValue:)),
              let x = propertyList[Self.xKey] as? Double,
              let y = propertyList[Self.yKey] as? Double
        else {
            return nil
        }
        self.init(anchor: WidgetAnchor(horizontal: horizontal, vertical: vertical), corner: CGPoint(x: x, y: y))
    }

    /// The corner of `frame` nearest to the edges of `visibleFrame` (`WidgetAnchor.nearest`).
    static func nearest(to frame: CGRect, in visibleFrame: CGRect) -> WidgetPosition {
        let anchor = WidgetAnchor.nearest(to: frame, in: visibleFrame)
        return WidgetPosition(anchor: anchor, corner: anchor.corner(of: frame))
    }

    /// The widget's frame at `size` with the corner in place.
    func frame(for size: CGSize) -> CGRect {
        let origin = CGPoint(x: anchor.horizontal == .right ? corner.x - size.width : corner.x, y: anchor.vertical == .top ? corner.y - size.height : corner.y)
        return CGRect(origin: origin, size: size)
    }

    /// Whether `frame` still has the corner here: true after the content resized around it,
    /// false after a drag.
    func isKept(by frame: CGRect) -> Bool {
        let current = anchor.corner(of: frame)
        return abs(current.x - corner.x) < Self.tolerance && abs(current.y - corner.y) < Self.tolerance
    }

    /// UserDefaults form: plain strings and numbers.
    var propertyList: [String: Any] {
        [Self.horizontalKey: anchor.horizontal.rawValue, Self.verticalKey: anchor.vertical.rawValue, Self.xKey: Double(corner.x), Self.yKey: Double(corner.y)]
    }
}
