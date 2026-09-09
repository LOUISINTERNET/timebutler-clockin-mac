import Foundation

/// The clock actions of the widget (FR-C6 to FR-C10, EC-5, EC-9).
extension ClockStore {
    static let discardedMessage = "Aufzeichnung verworfen."
    static let tooShortMessage = "Unter einer Minute, Aufzeichnung verworfen."

    /// start, pause, resume and cancel: the answer is the new status, the summary is reloaded.
    func perform(_ action: ClockAction) async {
        precondition(action != .stop, "Use stop(decision:) for the stop endpoint")
        guard beginAction(action) else {
            return
        }
        defer { isBusy = false }
        let expected = session
        do {
            let fetched = try await api.perform(action)
            guard session == expected else {
                return
            }
            adopt(status: fetched)
            pendingBreakRegulation = nil
            lastError = nil
            await reloadSummary()
        } catch {
            guard session == expected else {
                return
            }
            await handle(error, during: action)
        }
    }

    /// FR-C8: stop without a decision first; `apply` or `ignore` answer a break-regulation card.
    func stop(decision: BreakRegulationDecision? = nil) async {
        guard beginAction(.stop) else {
            return
        }
        defer { isBusy = false }
        let expected = session
        do {
            let result = try await api.stop(.standard(decision: decision))
            guard session == expected else {
                return
            }
            switch result {
            case .saved(let entry):
                pendingBreakRegulation = nil
                lastMessage = Self.savedMessage(for: entry)
            case .confirmationRequired(let regulation):
                pendingBreakRegulation = regulation
            case .discarded:
                pendingBreakRegulation = nil
                lastMessage = Self.discardedMessage
            }
            lastError = nil
            await refresh()
        } catch {
            guard session == expected else {
                return
            }
            if case APIError.http(409, _, _) = error, isYoungerThanAMinute {
                await discardYoungSession()
                return
            }
            await handle(error, during: .stop)
        }
    }

    /// Timebutler saves entries of at least one minute only; a younger session is discarded
    /// with `cancel` instead of making the user wait (FR-C8).
    private var isYoungerThanAMinute: Bool {
        guard let status, let fetchedAt, status.status != .waiting else {
            return false
        }
        return LiveClock.workSeconds(status: status, fetchedAt: fetchedAt, now: now()) < 60
    }

    private func discardYoungSession() async {
        logger.notice("Stop refused for a session under one minute, discarding it instead")
        let expected = session
        do {
            let fetched = try await api.perform(.cancel)
            guard session == expected else {
                return
            }
            adopt(status: fetched)
            lastError = nil
            lastMessage = Self.tooShortMessage
            await reloadSummary()
        } catch {
            guard session == expected else {
                return
            }
            await handle(error, during: .cancel)
        }
    }

    /// "Zurück" on the break-regulation card: nothing is sent.
    func dismissBreakRegulation() {
        pendingBreakRegulation = nil
    }

    /// "Gespeichert: 7:30 (Pause 0:30), korrigiert" (FR-C8), or just "Gespeichert." when
    /// Timebutler sends no details.
    static func savedMessage(for entry: SavedTimeEntry) -> String {
        guard let workedMinutes = entry.workedMinutes else {
            return "Gespeichert."
        }
        var message = "Gespeichert: \(DurationFormatting.signedHoursMinutes(minutes: workedMinutes))"
        if let breakMinutes = entry.breakMinutes, breakMinutes > 0 {
            message += " (Pause \(DurationFormatting.signedHoursMinutes(minutes: breakMinutes)))"
        }
        if entry.breakRegulationApplied == true {
            message += ", korrigiert"
        }
        return message
    }

    /// EC-9: a click while a call is running is ignored, the buttons are disabled anyway.
    /// A pending break-regulation card stays until the follow-up call succeeds, so a failure
    /// is shown on the card and the user can decide again.
    private func beginAction(_ action: ClockAction) -> Bool {
        guard !isBusy else {
            logger.notice("Ignored \(action.rawValue, privacy: .public) while another call is running")
            return false
        }
        isBusy = true
        lastMessage = nil
        return true
    }

    private func reloadSummary() async {
        let expected = session
        let version = currentFetchVersion
        do {
            let fetched = try await api.workSummary()
            guard session == expected, currentFetchVersion == version else {
                return
            }
            adopt(summary: fetched)
        } catch {
            logger.error("Work summary after action failed, keeping the previous one: \(String(describing: error), privacy: .private)")
        }
    }
}
