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
    }

    @Test func changesAreWrittenImmediatelyAndReadBack() throws {
        let (defaults, suite) = try temporaryDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        let preferences = Preferences(defaults: defaults)
        preferences.widgetVisible = false
        preferences.widgetOnAllSpaces = false
        preferences.launchAtLogin = true
        #expect(defaults.bool(forKey: "widgetVisible") == false)
        #expect(defaults.bool(forKey: "widgetOnAllSpaces") == false)
        #expect(defaults.bool(forKey: "launchAtLogin"))
        let reloaded = Preferences(defaults: defaults)
        #expect(!reloaded.widgetVisible)
        #expect(!reloaded.widgetOnAllSpaces)
        #expect(reloaded.launchAtLogin)
    }
}
