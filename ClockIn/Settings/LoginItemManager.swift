import Foundation
import Observation
import ServiceManagement

/// Launch at login through `SMAppService.mainApp` (design decision D15): no helper, no plist.
@MainActor
@Observable
final class LoginItemManager {
    private let logger = Log.logger(.settings)
    private(set) var status: SMAppService.Status = SMAppService.mainApp.status
    var errorMessage: String?

    var isEnabled: Bool {
        status == .enabled
    }

    /// macOS wants the user to allow the item in System Settings first.
    var requiresApproval: Bool {
        status == .requiresApproval
    }

    func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            errorMessage = nil
            logger.notice("Login item \(enabled ? "registered" : "unregistered", privacy: .public)")
        } catch {
            errorMessage = "Anmeldeobjekt konnte nicht geändert werden: \(error.localizedDescription)"
            logger.error("Login item change failed: \(String(describing: error), privacy: .public)")
        }
        refresh()
    }

    func refresh() {
        status = SMAppService.mainApp.status
        logger.notice("Login item status: \(String(describing: self.status), privacy: .public)")
    }

    func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }

    /// EC-8: the app was moved or renamed, so the registration vanished although it is wanted.
    func reregisterIfLost(wanted: Bool) {
        refresh()
        if wanted, status == .notFound {
            logger.notice("Login item lost, registering again")
            setEnabled(true)
        }
    }
}
