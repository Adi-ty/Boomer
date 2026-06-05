import ApplicationServices
import Foundation

/// Centralizes the runtime permission checks Boomer relies on. Features that need
/// a permission must check here and route the user to onboarding/Settings rather
/// than failing silently.
///
/// Privacy invariant: the monitors that use these permissions observe *activity
/// and window geometry only* — never keystroke content or window contents.
@MainActor
final class PermissionsManager {
    static let shared = PermissionsManager()

    private init() {}

    /// Accessibility is required for window tracking (sit on Terminal) and for the
    /// global keyboard activity monitor used by the typing animation.
    var hasAccessibility: Bool { AXIsProcessTrusted() }

    /// Prompts for Accessibility, opening System Settings if not yet granted.
    func requestAccessibility() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        _ = AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
    }
}
