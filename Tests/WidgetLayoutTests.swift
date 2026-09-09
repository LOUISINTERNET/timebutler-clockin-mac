import Foundation
import Testing

struct WidgetLayoutTests {
    private func status(_ name: String) throws -> TimeClockStatus {
        try Fixture.decode(TimeClockStatus.self, from: name)
    }

    @Test func signedOutStatesAlwaysShowTheNotice() throws {
        #expect(WidgetLayout.resolve(session: .notConfigured, collapsed: true, status: nil, hasPendingBreakRegulation: false, lastError: nil) == .signedOut)
        #expect(WidgetLayout.resolve(session: .expired, collapsed: false, status: try status("status-running"), hasPendingBreakRegulation: false, lastError: nil) == .signedOut)
    }

    @Test func breakRegulationCardWinsOverFolding() throws {
        #expect(WidgetLayout.resolve(session: .active(.apiToken), collapsed: true, status: try status("status-running"), hasPendingBreakRegulation: true, lastError: nil) == .breakRegulation)
    }

    @Test func unfoldedShowsTheFace() throws {
        #expect(WidgetLayout.resolve(session: .active(.apiToken), collapsed: false, status: try status("status-idle"), hasPendingBreakRegulation: false, lastError: nil) == .face)
    }

    @Test func foldedShowsTheLineWhileActiveAndTheSquareWhileStopped() throws {
        let session = SessionState.active(.oauth(email: "user@example.com"))
        #expect(WidgetLayout.resolve(session: session, collapsed: true, status: try status("status-running"), hasPendingBreakRegulation: false, lastError: nil) == .line)
        #expect(WidgetLayout.resolve(session: session, collapsed: true, status: try status("status-paused"), hasPendingBreakRegulation: false, lastError: nil) == .line)
        #expect(WidgetLayout.resolve(session: session, collapsed: true, status: try status("status-idle"), hasPendingBreakRegulation: false, lastError: nil) == .square)
    }

    @Test func squareNeedsAStartableClockAndNoError() throws {
        let session = SessionState.active(.apiToken)
        let terminalOnly = TimeClockStatus(status: .idle, startTimestamp: nil, pauseTimestamp: nil, workTimeElapsedSeconds: 0, breakElapsedSeconds: 0, accumulatedBreakSeconds: 0, waitSeconds: nil, isBusinessTripActive: nil, startOnlyOnTerminal: true, pauseOnlyOnTerminal: false, stopOnlyOnTerminal: false)
        #expect(WidgetLayout.resolve(session: session, collapsed: true, status: terminalOnly, hasPendingBreakRegulation: false, lastError: nil) == .line)
        #expect(WidgetLayout.resolve(session: session, collapsed: true, status: try status("status-idle"), hasPendingBreakRegulation: false, lastError: "Keine Verbindung zu Timebutler.") == .line)
        #expect(WidgetLayout.resolve(session: session, collapsed: true, status: nil, hasPendingBreakRegulation: false, lastError: nil) == .line)
    }
}
