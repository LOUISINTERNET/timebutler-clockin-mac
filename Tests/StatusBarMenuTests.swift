import AppKit
import Foundation
import Testing

@MainActor
struct StatusBarMenuTests {
    private func makeMenu(credentials: Credentials?) async throws -> (StatusBarMenu, Preferences, TestStore) {
        let suite = "app.clockin.tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        let preferences = Preferences(defaults: defaults)
        let harness = try TestStore(credentials: credentials, routes: TestStore.running)
        await harness.store.start()
        let menu = StatusBarMenu(store: harness.store, preferences: preferences, toggleWidget: {}, openSettings: {})
        return (menu, preferences, harness)
    }

    @Test func itemsFollowTheRequiredOrderAndShortcuts() async throws {
        let (menu, _, harness) = try await makeMenu(credentials: .apiToken("tb_secret"))
        defer { harness.store.stopObserving() }
        let built = menu.build()
        #expect(built.items.map(\.title) == ["Widget ausblenden", "Jetzt aktualisieren", "", "Einstellungen…", "", "Clock In beenden"])
        #expect(built.items.map(\.isSeparatorItem) == [false, false, true, false, true, false])
        #expect(built.items.map(\.keyEquivalent) == ["", "", "", ",", "", "q"])
        #expect(built.items[1].isEnabled)
    }

    @Test func refreshIsDisabledWithoutASession() async throws {
        let (menu, _, harness) = try await makeMenu(credentials: nil)
        defer { harness.store.stopObserving() }
        #expect(!menu.build().items[1].isEnabled)
    }

    @Test func refreshIsDisabledWhenExpired() async throws {
        let (menu, _, harness) = try await makeMenu(credentials: .apiToken("tb_secret"))
        defer { harness.store.stopObserving() }
        await harness.sessionManager.markExpired()
        await harness.store.synchronizeSession()
        #expect(!menu.build().items[1].isEnabled)
    }

    @Test func widgetItemReflectsVisibility() async throws {
        let (menu, preferences, harness) = try await makeMenu(credentials: nil)
        defer { harness.store.stopObserving() }
        preferences.widgetVisible = false
        #expect(menu.build().items[0].title == "Widget einblenden")
        preferences.widgetVisible = true
        #expect(menu.build().items[0].title == "Widget ausblenden")
    }
}
