import Foundation
import Testing

@MainActor
struct PreferencesTests {
    private func temporaryDefaults() throws -> (UserDefaults, String) {
        let suite = "app.clockin.tests.\(UUID().uuidString)"
        return (try #require(UserDefaults(suiteName: suite)), suite)
    }

    @Test func bothFlagsDefaultToOn() throws {
        let (defaults, suite) = try temporaryDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        let preferences = Preferences(defaults: defaults)
        #expect(preferences.widgetVisible)
        #expect(preferences.widgetOnAllSpaces)
        #expect(!preferences.launchAtLogin)
        #expect(!preferences.widgetCollapsed)
        #expect(preferences.widgetAlwaysOnTop)
    }

    @Test func changesAreWrittenImmediatelyAndReadBack() throws {
        let (defaults, suite) = try temporaryDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        let preferences = Preferences(defaults: defaults)
        preferences.widgetVisible = false
        preferences.widgetOnAllSpaces = false
        preferences.launchAtLogin = true
        preferences.widgetCollapsed = true
        preferences.widgetAlwaysOnTop = false
        #expect(defaults.bool(forKey: "widgetCollapsed"))
        #expect(defaults.bool(forKey: "widgetAlwaysOnTop") == false)
        #expect(defaults.bool(forKey: "widgetVisible") == false)
        #expect(defaults.bool(forKey: "widgetOnAllSpaces") == false)
        #expect(defaults.bool(forKey: "launchAtLogin"))
        let reloaded = Preferences(defaults: defaults)
        #expect(!reloaded.widgetVisible)
        #expect(!reloaded.widgetOnAllSpaces)
        #expect(reloaded.launchAtLogin)
        #expect(reloaded.widgetCollapsed)
        #expect(!reloaded.widgetAlwaysOnTop)
    }

    @Test func widgetPositionStartsEmptyAndSurvivesAReload() throws {
        let (defaults, suite) = try temporaryDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        let preferences = Preferences(defaults: defaults)
        #expect(preferences.widgetPosition == nil)
        let position = WidgetPosition(anchor: WidgetAnchor(horizontal: .right, vertical: .bottom), corner: CGPoint(x: 1884, y: 95))
        preferences.widgetPosition = position
        #expect(Preferences(defaults: defaults).widgetPosition == position)
        preferences.widgetPosition = nil
        #expect(defaults.object(forKey: "widgetPosition") == nil)
    }

    @Test func malformedWidgetPositionFallsBackToNone() throws {
        let (defaults, suite) = try temporaryDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(["horizontal": "middle", "vertical": "top", "x": 1.0, "y": 2.0], forKey: "widgetPosition")
        #expect(Preferences(defaults: defaults).widgetPosition == nil)
        defaults.set("1810 1210 74 60", forKey: "widgetPosition")
        #expect(Preferences(defaults: defaults).widgetPosition == nil)
    }
}
