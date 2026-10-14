import Foundation

/// Short retries after a refresh that found no connection (FR-C14). After a reboot the login
/// item starts before Wi-Fi is up; without them the first status waited for the next poll.
extension ClockStore {
    static let defaultConnectionRetryDelays: [Duration] = [.seconds(2), .seconds(5), .seconds(10), .seconds(20)]

    var isConnectionRetryPending: Bool {
        connectionRetry != nil
    }

    /// The refresh of wake, network return and connection retry. It waits while a clock action
    /// runs, because the action reloads the status itself (EC-9). A launch without connection
    /// also missed the profile, so the first status that comes back loads it (EC-6).
    func refreshUnlessBusy(after trigger: String) async {
        if isBusy {
            logger.notice("\(trigger, privacy: .public) while a clock action is running, the action's own refresh follows")
            return
        }
        logger.notice("\(trigger, privacy: .public), refreshing")
        if await refresh(), profile == nil {
            await loadProfile()
        }
    }

    /// Plans the next retry unless one is waiting already. After the last delay the regular
    /// poll and the network path monitor take over.
    func scheduleConnectionRetry() {
        guard connectionRetry == nil else {
            return
        }
        guard connectionRetryAttempt < connectionRetryDelays.count else {
            logger.notice("Connection retries used up, the regular poll takes over")
            return
        }
        let delay = connectionRetryDelays[connectionRetryAttempt]
        connectionRetryAttempt += 1
        logger.notice("No connection, retry \(self.connectionRetryAttempt, privacy: .public) of \(self.connectionRetryDelays.count, privacy: .public) in \(String(describing: delay), privacy: .public)")
        connectionRetry = Task { [weak self] in
            // The suspending clock stops while the Mac sleeps, so a waiting retry does not
            // fire at wake on top of the wake refresh.
            do {
                try await Task.sleep(for: delay, clock: .suspending)
            } catch {
                return
            }
            // A cancel that arrived after the sleep ended but before this task resumed.
            guard !Task.isCancelled, let self else {
                return
            }
            self.connectionRetry = nil
            await self.refreshUnlessBusy(after: "Connection retry")
        }
    }

    /// Called when a status arrived or the session changed: drops a waiting retry and starts
    /// the next outage with the first delay again.
    func resetConnectionRetry() {
        connectionRetry?.cancel()
        connectionRetry = nil
        connectionRetryAttempt = 0
    }
}
