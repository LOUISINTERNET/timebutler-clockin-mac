import CoreGraphics
import Testing

struct WidgetPositionTests {
    private let tile = CGSize(width: 80, height: 48)
    private let face = CGSize(width: 260, height: 300)

    @Test func nearestPinsTheCornerOfTheFrameOnItsQuarter() {
        let visibleFrame = CGRect(x: 0, y: 0, width: 1000, height: 800)
        let position = WidgetPosition.nearest(to: CGRect(origin: CGPoint(x: 900, y: 20), size: tile), in: visibleFrame)
        #expect(position == WidgetPosition(anchor: WidgetAnchor(horizontal: .right, vertical: .bottom), corner: CGPoint(x: 980, y: 20)))
    }

    @Test func everySizeKeepsThePinnedCornerInPlace() {
        let topRight = WidgetPosition(anchor: WidgetAnchor(horizontal: .right, vertical: .top), corner: CGPoint(x: 980, y: 768))
        #expect(topRight.frame(for: face) == CGRect(x: 720, y: 468, width: 260, height: 300))
        #expect(topRight.frame(for: tile) == CGRect(x: 900, y: 720, width: 80, height: 48))
        let bottomRight = WidgetPosition(anchor: WidgetAnchor(horizontal: .right, vertical: .bottom), corner: CGPoint(x: 980, y: 20))
        #expect(bottomRight.frame(for: face) == CGRect(x: 720, y: 20, width: 260, height: 300))
        let bottomLeft = WidgetPosition(anchor: WidgetAnchor(horizontal: .left, vertical: .bottom), corner: CGPoint(x: 20, y: 20))
        #expect(bottomLeft.frame(for: tile) == CGRect(x: 20, y: 20, width: 80, height: 48))
        let topLeft = WidgetPosition(anchor: WidgetAnchor(horizontal: .left, vertical: .top), corner: CGPoint(x: 20, y: 768))
        #expect(topLeft.frame(for: face) == CGRect(x: 20, y: 468, width: 260, height: 300))
    }

    @Test func aResizeAroundTheCornerKeepsItButADragDoesNot() {
        let position = WidgetPosition(anchor: WidgetAnchor(horizontal: .right, vertical: .bottom), corner: CGPoint(x: 980, y: 20))
        #expect(position.isKept(by: position.frame(for: CGSize(width: 247.33, height: 301.67))))
        let folded = position.frame(for: tile)
        #expect(!position.isKept(by: folded.offsetBy(dx: -1, dy: 0)))
        #expect(!position.isKept(by: folded.offsetBy(dx: 0, dy: 1)))
    }

    @Test func propertyListRoundTrips() {
        let position = WidgetPosition(anchor: WidgetAnchor(horizontal: .right, vertical: .top), corner: CGPoint(x: 2405.5, y: -120))
        #expect(WidgetPosition(propertyList: position.propertyList) == position)
    }

    @Test func malformedPropertyListsAreRejected() {
        let valid: [String: Any] = ["horizontal": "right", "vertical": "top", "x": 2405.5, "y": 3160.0]
        #expect(WidgetPosition(propertyList: valid) == WidgetPosition(anchor: WidgetAnchor(horizontal: .right, vertical: .top), corner: CGPoint(x: 2405.5, y: 3160)))
        #expect(WidgetPosition(propertyList: valid.merging(["horizontal": "centre"]) { $1 }) == nil)
        #expect(WidgetPosition(propertyList: valid.merging(["vertical": 1]) { $1 }) == nil)
        #expect(WidgetPosition(propertyList: valid.merging(["x": "2405"]) { $1 }) == nil)
        #expect(WidgetPosition(propertyList: valid.filter { $0.key != "y" }) == nil)
    }
}
