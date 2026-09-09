import Testing

struct SmokeTests {
    @Test func bundleIdentifierIsClockIn() {
        #expect(AppIdentity.bundleIdentifier == "app.clockin")
    }
}
