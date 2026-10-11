import Foundation
import Sparkle

/// Sparkle behind `UpdateState` (design decisions E5, E6 of the release plan). Scheduled checks
/// run once a day, at launch only when the last one is older than a day (FR-1); the menu and the
/// about tab start a check with a dialog (FR-2).
/// A scheduled check that finds an update outside immediate focus stays quiet and only changes
/// the menu entry (FR-4); Sparkle's gentle reminders for background apps.
@MainActor
final class Updater: NSObject, SPUStandardUserDriverDelegate {
    private let updateState: UpdateState
    private let logger = Log.logger(.update)
    private var canCheckObservation: NSKeyValueObservation?

    /// Lazy, because the controller needs `self` as its user driver delegate.
    private lazy var controller = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: self)

    init(updateState: UpdateState) {
        self.updateState = updateState
        super.init()
        // FR-3: KVO, because `canCheckForUpdates` is a KVO property and the app has no Combine.
        canCheckObservation = controller.updater.observe(\.canCheckForUpdates, options: [.initial, .new]) { [weak self] updater, _ in
            MainActor.assumeIsolated {
                self?.updateState.canCheckForUpdates = updater.canCheckForUpdates
            }
        }
        logger.notice("Updater started, automatic checks \(self.controller.updater.automaticallyChecksForUpdates, privacy: .public), can check \(self.updateState.canCheckForUpdates, privacy: .public)")
    }

    func checkForUpdates() {
        logger.notice("Update check started by the user")
        controller.checkForUpdates(nil)
    }

    // MARK: - SPUStandardUserDriverDelegate

    // Sparkle declares this protocol without an actor but calls it on the main thread only.

    nonisolated var supportsGentleScheduledUpdateReminders: Bool {
        true
    }

    /// Sparkle shows a scheduled update itself only in immediate focus, shortly after launch.
    nonisolated func standardUserDriverShouldHandleShowingScheduledUpdate(_ update: SUAppcastItem, andInImmediateFocus immediateFocus: Bool) -> Bool {
        immediateFocus
    }

    /// FR-4: an update Sparkle leaves to the app goes into the menu; the app stays inactive.
    nonisolated func standardUserDriverWillHandleShowingUpdate(_ handleShowingUpdate: Bool, forUpdate update: SUAppcastItem, state: SPUUserUpdateState) {
        guard !handleShowingUpdate else {
            return
        }
        let version = update.displayVersionString
        MainActor.assumeIsolated {
            updateState.pendingVersion = version
            logger.notice("Update \(version, privacy: .public) found, offered in the menu")
        }
    }

    nonisolated func standardUserDriverWillFinishUpdateSession() {
        MainActor.assumeIsolated {
            updateState.pendingVersion = nil
            logger.notice("Update session finished")
        }
    }
}
