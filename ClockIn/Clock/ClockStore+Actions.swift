import Foundation

/// The clock actions of the widget (FR-C6 to FR-C10, EC-5, EC-9).
extension ClockStore {
    static let discardedMessage = "Aufzeichnung verworfen."

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
                lastMessage = Self.savedMessage(for: entry)
            case .confirmationRequired(let regulation):
                pendingBreakRegulation = regulation
            case .discarded:
                lastMessage = Self.discardedMessage
            }
            lastError = nil
            await refresh()
        } catch {
            guard session == expected else {
                return
            }
            await handle(error, during: .stop)
        }
    }

    /// "Zurück" on the break-regulation card: nothing is sent.
    func dismissBreakRegulation() {
        pendingBreakRegulation = nil
    }

    /// "Gespeichert: 7:30 (Pause 0:30), korrigiert" (FR-C8).
    static func savedMessage(for entry: SavedTimeEntry) -> String {
        var message = "Gespeichert: \(DurationFormatting.signedHoursMinutes(minutes: entry.workedMinutes))"
        if entry.breakMinutes > 0 {
            message += " (Pause \(DurationFormatting.signedHoursMinutes(minutes: entry.breakMinutes)))"
        }
        if entry.breakRegulationApplied {
            message += ", korrigiert"
        }
        return message
    }

    /// EC-9: a click while a call is running is ignored, the buttons are disabled anyway.
    private func beginAction(_ action: ClockAction) -> Bool {
        guard !isBusy else {
            logger.notice("Ignored \(action.rawValue, privacy: .public) while another call is running")
            return false
        }
        isBusy = true
        lastMessage = nil
        pendingBreakRegulation = nil
        return true
    }

    private func reloadSummary() async {
        let expected = session
        do {
            let fetched = try await api.workSummary()
            guard session == expected else {
                return
            }
            summary = fetched
        } catch {
            logger.error("Work summary after action failed, keeping the previous one: \(String(describing: error), privacy: .public)")
        }
    }
}
