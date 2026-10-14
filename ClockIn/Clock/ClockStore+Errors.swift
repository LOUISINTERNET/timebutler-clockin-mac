import Foundation

/// The one place that turns thrown errors into `lastError` and follow-up actions (D10).
extension ClockStore {
    /// Records the German message in `lastError` and performs the follow-up the
    /// requirements demand for the failure (FR-C10, FR-C12, FR-C14, FR-S5). After a failed
    /// action the server may have changed state anyway (an answer that could not be decoded,
    /// a conflict), so the status is reloaded unless the request never reached the server.
    /// A refresh without connection is retried soon; a failed action is not, because the
    /// retry's refresh would clear the action's error.
    func handle(_ error: any Error, during action: ClockAction?) async {
        if error is CancellationError {
            logger.notice("Call cancelled by a session change")
            return
        }
        let text = message(for: error)
        lastError = text
        logger.error("\(action?.rawValue ?? "refresh", privacy: .public) failed: \(text, privacy: .public)")
        switch error {
        case APIError.http(let code, _, _):
            await react(toHTTPStatus: code, action: action)
        case APIError.unreadableResponse where action != nil:
            await reloadStatusAfterActionFailure()
        case SessionError.expired:
            await synchronizeSession()
        case APIError.transport where action == nil, SessionError.transport where action == nil:
            scheduleConnectionRetry()
        default:
            break
        }
    }

    func message(for error: any Error) -> String {
        switch error {
        case let apiError as APIError:
            apiError.userMessage
        case let sessionError as SessionError:
            sessionError.userMessage
        case let keychainError as KeychainError:
            keychainError.message
        default:
            "Unerwarteter Fehler: \(String(describing: error))"
        }
    }

    private func react(toHTTPStatus code: Int, action: ClockAction?) async {
        switch code {
        case 401:
            await sessionManager.markExpired()
            await synchronizeSession()
        case 409 where action != nil:
            await reloadStatusAfterActionFailure()
        case 429:
            pollingSkipRequested = true
        default:
            break
        }
    }

    /// FR-C10: after a failed action the buttons must match reality; `lastError` stays visible.
    private func reloadStatusAfterActionFailure() async {
        let expected = session
        let version = currentFetchVersion
        do {
            let fetched = try await api.status()
            guard session == expected, currentFetchVersion == version else {
                return
            }
            adopt(status: fetched)
            await reloadSummaryAfterActionFailure()
        } catch {
            logger.error("Status reload after a failed action failed: \(String(describing: error), privacy: .private)")
        }
    }

    /// A saved stop changes today's totals even when its answer was unreadable.
    private func reloadSummaryAfterActionFailure() async {
        let expected = session
        let version = currentFetchVersion
        do {
            let fetched = try await api.workSummary()
            guard session == expected, currentFetchVersion == version else {
                return
            }
            adopt(summary: fetched)
        } catch {
            logger.error("Work summary reload after a failed action failed: \(String(describing: error), privacy: .private)")
        }
    }
}
