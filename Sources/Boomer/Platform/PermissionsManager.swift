import AppKit
import ApplicationServices
import CoreGraphics
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

    // MARK: - Accessibility (window tracking: sit on Terminal)

    var hasAccessibility: Bool {
        AXIsProcessTrusted()
    }

    /// Prompts for Accessibility and opens System Settings (covers the case
    /// where the prompt was previously dismissed and won't re-appear).
    func requestAccessibility() {
        // The imported C global `kAXTrustedCheckOptionPrompt` is a non-Sendable
        // mutable global, which Swift 6 strict concurrency rejects. Its documented
        // value is the string below, so we use that directly.
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        if !AXIsProcessTrustedWithOptions(options) {
            openSettings(pane: "Privacy_Accessibility")
        }
    }

    // MARK: - Input Monitoring (typing activity — never content)

    var hasInputMonitoring: Bool {
        CGPreflightListenEventAccess()
    }

    func requestInputMonitoring() {
        if !CGRequestListenEventAccess() {
            openSettings(pane: "Privacy_ListenEvent")
        }
    }

    // MARK: - Helpers

    private func openSettings(pane: String) {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)")
        else { return }
        NSWorkspace.shared.open(url)
    }
}
