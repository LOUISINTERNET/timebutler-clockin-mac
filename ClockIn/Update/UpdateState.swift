import Observation

/// What the status menu and the about tab show of Sparkle (FR-3, FR-4). It stays free of
/// Sparkle, so the views and their tests do not link the framework; `Updater` writes it.
@MainActor
@Observable
final class UpdateState {
    /// FR-3: false while Sparkle cannot start a check, for example during a running one.
    var canCheckForUpdates = false

    /// FR-4: the version a scheduled check found and left to the menu; nil otherwise.
    var pendingVersion: String?

    var menuTitle: String {
        guard let pendingVersion else {
            return "Nach Updates suchen…"
        }
        return "Update auf \(pendingVersion) installieren…"
    }
}
