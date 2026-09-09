/// `TimeClockStatusDto` from the Timebutler API v2. Optionals mirror the fields the
/// OpenAPI spec marks as nullable; everything else is required.
struct TimeClockStatus: Codable, Sendable, Equatable {
    let status: ClockState
    /// Unix milliseconds of the current clock-in, nil while idle.
    let startTimestamp: Int64?
    /// Unix milliseconds of the current break, nil unless paused.
    let pauseTimestamp: Int64?
    let workTimeElapsedSeconds: Int
    let breakElapsedSeconds: Int
    let accumulatedBreakSeconds: Int
    let waitSeconds: Int?
    let isBusinessTripActive: Bool
    let startOnlyOnTerminal: Bool
    let pauseOnlyOnTerminal: Bool
    let stopOnlyOnTerminal: Bool
}

extension TimeClockStatus {
    var canStart: Bool {
        status == .idle && !startOnlyOnTerminal
    }

    var canPause: Bool {
        status == .running && !pauseOnlyOnTerminal
    }

    var canResume: Bool {
        status == .paused && !pauseOnlyOnTerminal
    }

    var canStop: Bool {
        status.isActive && !stopOnlyOnTerminal
    }

    /// True when the company restricts every action of the current state to the terminal.
    var allActionsTerminalOnly: Bool {
        !canStart && !canPause && !canResume && !canStop
    }
}
