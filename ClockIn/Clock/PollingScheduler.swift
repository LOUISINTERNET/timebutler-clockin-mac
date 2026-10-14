import AppKit
import Foundation

/// Refreshes the store every minute, right after the Mac wakes up and when the network comes
/// back (FR-C1, EC-2, FR-C14). One planned poll is skipped after a 429 (FR-C12).
@MainActor
final class PollingScheduler {
    private let store: ClockStore
    private let networkPaths: any NetworkPathSource
    private let interval: Duration
    private let logger = Log.logger(.clock)
    private var loop: Task<Void, Never>?
    private var wakeObserver: (any NSObjectProtocol)?
    private var pathObservation: Task<Void, Never>?
    private var isOffline = false

    init(store: ClockStore, networkPaths: any NetworkPathSource, interval: Duration = .seconds(60)) {
        self.store = store
        self.networkPaths = networkPaths
        self.interval = interval
    }

    func start() {
        stop()
        let interval = interval
        loop = Task { [weak self] in
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: interval)
                } catch {
                    return
                }
                guard let self else {
                    return
                }
                await self.tick()
            }
        }
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                await self?.wake()
            }
        }
        isOffline = false
        let paths = networkPaths.pathAvailability()
        pathObservation = Task { [weak self] in
            for await isSatisfied in paths {
                // The stream still hands out values buffered before `stop()` cancelled it.
                guard !Task.isCancelled, let self else {
                    return
                }
                await self.networkPathChanged(isSatisfied: isSatisfied)
            }
        }
        logger.notice("Polling every \(String(describing: interval), privacy: .public)")
    }

    func stop() {
        loop?.cancel()
        loop = nil
        pathObservation?.cancel()
        pathObservation = nil
        if let wakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver)
            self.wakeObserver = nil
        }
    }

    /// One planned poll. Honours the skip the store requests after a 429 and does nothing
    /// when `stop()` cancelled the loop while this tick was already on its way.
    func tick() async {
        guard !Task.isCancelled else {
            return
        }
        if store.isBusy {
            logger.notice("Skipping a poll while a clock action is running")
            return
        }
        if store.pollingSkipRequested {
            store.pollingSkipRequested = false
            logger.notice("Skipping one poll after a rate limit")
            return
        }
        await store.refresh()
    }

    func wake() async {
        await store.refreshUnlessBusy(after: "Mac woke up")
    }

    /// FR-C14: refreshes when the network comes back after it was gone, e.g. when Wi-Fi joins
    /// after login. The first value counts as a usable path, and a change between two usable
    /// paths (Wi-Fi to Ethernet) is no return. The short retries start over, because the first
    /// request right after the return may still fail while DNS or DHCP settle.
    func networkPathChanged(isSatisfied: Bool) async {
        let wasOffline = isOffline
        isOffline = !isSatisfied
        if isOffline && !wasOffline {
            logger.notice("No usable network path")
        }
        guard wasOffline && isSatisfied else {
            return
        }
        store.resetConnectionRetry()
        await store.refreshUnlessBusy(after: "Network is back")
    }
}
