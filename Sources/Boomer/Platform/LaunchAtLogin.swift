import Foundation
import ServiceManagement

/// Register/unregister the app as a login item via `SMAppService` (the user
/// can always override in System Settings → General → Login Items).
@MainActor
enum LaunchAtLogin {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func toggle() {
        do {
            if isEnabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            // Registration can fail for unsigned dev builds; the menu simply
            // keeps showing the real status.
        }
    }
}
