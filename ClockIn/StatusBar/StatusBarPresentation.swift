import Foundation

/// Symbol and title of the menu bar item for one moment in time (FR-M1, FR-M2).
struct StatusBarPresentation: Equatable, Sendable {
    static let signedOutSymbol = "clock.badge.exclamationmark"

    let symbolName: String
    let title: String

    static func make(session: SessionState, status: TimeClockStatus?, fetchedAt: Date?, now: Date) -> StatusBarPresentation {
        guard session.isActive else {
            return StatusBarPresentation(symbolName: signedOutSymbol, title: "")
        }
        guard let status, let fetchedAt else {
            return StatusBarPresentation(symbolName: symbol(for: .idle), title: "")
        }
        guard status.status.isActive else {
            return StatusBarPresentation(symbolName: symbol(for: status.status), title: "")
        }
        let seconds = LiveClock.workSeconds(status: status, fetchedAt: fetchedAt, now: now)
        return StatusBarPresentation(symbolName: symbol(for: status.status), title: DurationFormatting.hoursMinutes(seconds: seconds))
    }

    static func symbol(for state: ClockState) -> String {
        switch state {
        case .idle: "clock"
        case .running: "play.circle.fill"
        case .paused: "pause.circle.fill"
        case .waiting: "clock.badge"
        }
    }
}
