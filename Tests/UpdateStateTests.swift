import Testing

@MainActor
struct UpdateStateTests {
    @Test func startsUnableToCheckWithoutAPendingVersion() {
        let state = UpdateState()
        #expect(!state.canCheckForUpdates)
        #expect(state.pendingVersion == nil)
    }

    @Test func menuTitleOffersACheckWithoutAPendingVersion() {
        #expect(UpdateState().menuTitle == "Nach Updates suchen…")
    }

    @Test func menuTitleNamesThePendingVersion() {
        let state = UpdateState()
        state.pendingVersion = "2.0.0"
        #expect(state.menuTitle == "Update auf 2.0.0 installieren…")
    }
}
