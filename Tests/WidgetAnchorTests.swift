import AppKit
import Testing

struct WidgetAnchorTests {
    /// A 1000 × 800 point visible area with its origin at the bottom left, as AppKit counts.
    private let visibleFrame = CGRect(x: 0, y: 0, width: 1000, height: 800)
    private let tile = CGSize(width: 80, height: 48)

    @Test func eachQuarterOfTheScreenPinsItsOwnCorner() {
        #expect(WidgetAnchor.nearest(to: CGRect(origin: CGPoint(x: 900, y: 720), size: tile), in: visibleFrame) == WidgetAnchor(horizontal: .right, vertical: .top))
        #expect(WidgetAnchor.nearest(to: CGRect(origin: CGPoint(x: 20, y: 720), size: tile), in: visibleFrame) == WidgetAnchor(horizontal: .left, vertical: .top))
        #expect(WidgetAnchor.nearest(to: CGRect(origin: CGPoint(x: 900, y: 20), size: tile), in: visibleFrame) == WidgetAnchor(horizontal: .right, vertical: .bottom))
        #expect(WidgetAnchor.nearest(to: CGRect(origin: CGPoint(x: 20, y: 20), size: tile), in: visibleFrame) == WidgetAnchor(horizontal: .left, vertical: .bottom))
    }

    @Test func theMiddleOfTheWidgetDecidesAndTheExactCentreStaysTopLeft() {
        let straddlingRight = CGRect(origin: CGPoint(x: 470, y: 360), size: tile)
        #expect(WidgetAnchor.nearest(to: straddlingRight, in: visibleFrame) == WidgetAnchor(horizontal: .right, vertical: .bottom))
        let centred = CGRect(origin: CGPoint(x: 460, y: 376), size: tile)
        #expect(WidgetAnchor.nearest(to: centred, in: visibleFrame) == WidgetAnchor(horizontal: .left, vertical: .top))
    }

    @Test func halvesAreMeasuredOnTheWidgetsOwnScreen() {
        let secondScreen = CGRect(x: 1000, y: -200, width: 1000, height: 800)
        let nearItsTopLeft = CGRect(origin: CGPoint(x: 1020, y: 520), size: tile)
        #expect(WidgetAnchor.nearest(to: nearItsTopLeft, in: secondScreen) == WidgetAnchor(horizontal: .left, vertical: .top))
    }

    @Test func edgesMapToTheWindowAnchorAttributes() {
        let bottomRight = WidgetAnchor(horizontal: .right, vertical: .bottom)
        #expect(bottomRight.horizontalAttribute == .right)
        #expect(bottomRight.verticalAttribute == .bottom)
        let topLeft = WidgetAnchor(horizontal: .left, vertical: .top)
        #expect(topLeft.horizontalAttribute == .left)
        #expect(topLeft.verticalAttribute == .top)
    }
}
