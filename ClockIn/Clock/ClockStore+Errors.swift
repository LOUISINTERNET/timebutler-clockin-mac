import Foundation

/// The one place that turns thrown errors into `lastError` and follow-up actions (D10).
extension ClockStore {
    /// Records the German message in `lastError` and performs the follow-up the
    /// requirements demand for the failure (FR-C10, FR-C12, FR-S5).
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
        case SessionError.expired:
            await synchronizeSession()
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
            await reloadStatusAfterConflict()
        case 429:
            pollingSkipRequested = true
        default:
            break
        }
    }

    /// FR-C10: after a conflict the buttons must match reality; `lastError` stays visible.
    private func reloadStatusAfterConflict() async {
        let expected = session
        let version = currentStatusVersion
        do {
            let fetched = try await api.status()
            guard session == expected, currentStatusVersion == version else {
                return
            }
            adopt(status: fetched)
        } catch {
            logger.error("Status reload after conflict failed: \(String(describing: error), privacy: .public)")
        }
    }
}
