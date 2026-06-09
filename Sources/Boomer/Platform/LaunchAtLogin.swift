import AppKit
import Observation
import ServiceManagement

/// Registers/unregisters the app as a login item via `SMAppService`, exposing
/// the *live* status so the menu's checkmark stays accurate and failures aren't
/// swallowed. The user can always override in System Settings → General →
/// Login Items.
///
/// Note: a login item points at the app's current location. For this to be
/// useful the app should live somewhere stable (e.g. `/Applications`) — a build
/// launched from Xcode's DerivedData will register that throwaway path.
@MainActor
@Observable
final class LaunchAtLogin {
    static let shared = LaunchAtLogin()

    /// The real registration status, re-read after every change.
    private(set) var status: SMAppService.Status

    private init() {
        status = SMAppService.mainApp.status
    }

    var isEnabled: Bool {
        status == .enabled
    }

    /// Re-read status (it can change in System Settings behind our back).
    func refresh() {
        status = SMAppService.mainApp.status
    }

    func toggle() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            // Don't fail silently: open the Login Items pane so the user can
            // flip it by hand (registration can be refused for an unsigned or
            // relocated build).
            SMAppService.openSystemSettingsLoginItems()
        }
        refresh()
        // Newly-registered items can land in a "needs your approval" state;
        // send the user straight to the toggle.
        if status == .requiresApproval {
            SMAppService.openSystemSettingsLoginItems()
        }
    }
}
