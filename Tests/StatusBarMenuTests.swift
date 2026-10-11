import AppKit
import Foundation
import Testing

@MainActor
struct StatusBarMenuTests {
    private func makeMenu(
        credentials: Credentials?,
        updateState: UpdateState = UpdateState(),
        checkForUpdates: @escaping () -> Void = {}
    ) async throws -> (StatusBarMenu, Preferences, TestStore) {
        let suite = "app.clockin.tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        let preferences = Preferences(defaults: defaults)
        let harness = try TestStore(credentials: credentials, routes: TestStore.running)
        await harness.store.start()
        let menu = StatusBarMenu(
            store: harness.store,
            preferences: preferences,
            updateState: updateState,
            toggleWidget: {},
            openSettings: {},
            checkForUpdates: checkForUpdates
        )
        return (menu, preferences, harness)
    }

    private func checkableUpdateState(pendingVersion: String? = nil) -> UpdateState {
        let updateState = UpdateState()
        updateState.canCheckForUpdates = true
        updateState.pendingVersion = pendingVersion
        return updateState
    }

    @Test func itemsFollowTheRequiredOrderAndShortcuts() async throws {
        let (menu, _, harness) = try await makeMenu(credentials: .apiToken("tb_secret"), updateState: checkableUpdateState())
        defer { harness.store.stopObserving() }
        let built = menu.build()
        #expect(built.items.map(\.title) == ["Widget ausblenden", "Jetzt aktualisieren", "Nach Updates suchen…", "", "Einstellungen…", "", "Clock In beenden"])
        #expect(built.items.map(\.isSeparatorItem) == [false, false, false, true, false, true, false])
        #expect(built.items.map(\.keyEquivalent) == ["", "", "", "", ",", "", "q"])
        #expect(built.items[1].isEnabled)
        #expect(built.items[2].isEnabled)
    }

    @Test func updateItemIsDisabledWhileSparkleCannotCheck() async throws {
        let (menu, _, harness) = try await makeMenu(credentials: .apiToken("tb_secret"), updateState: UpdateState())
        defer { harness.store.stopObserving() }
        let item = menu.build().items[2]
        #expect(item.title == "Nach Updates suchen…")
        #expect(!item.isEnabled)
    }

    @Test func updateItemNamesAPendingVersion() async throws {
        let (menu, _, harness) = try await makeMenu(credentials: .apiToken("tb_secret"), updateState: checkableUpdateState(pendingVersion: "1.0.1"))
        defer { harness.store.stopObserving() }
        let item = menu.build().items[2]
        #expect(item.title == "Update auf 1.0.1 installieren…")
        #expect(item.isEnabled)
    }

    @Test func updateItemStartsExactlyOneCheck() async throws {
        var checks = 0
        let (menu, _, harness) = try await makeMenu(credentials: nil, updateState: checkableUpdateState(), checkForUpdates: { checks += 1 })
        defer { harness.store.stopObserving() }
        // performActionForItem(at:) sends the action through NSApp, and the test bundle has
        // no host app that would have created it.
        _ = NSApplication.shared
        menu.build().performActionForItem(at: 2)
        #expect(checks == 1)
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
