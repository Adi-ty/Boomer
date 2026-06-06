import AppKit
import ApplicationServices
import CoreGraphics
import Foundation
import Observation
import UserNotifications

/// Centralizes the runtime permission checks Boomer relies on. Features that need
/// a permission must check here and route the user to onboarding/Settings rather
/// than failing silently.
///
/// Privacy invariant: the monitors that use these permissions observe *activity
/// and window geometry only* — never keystroke content or window contents.
@MainActor
@Observable
final class PermissionsManager {
    static let shared = PermissionsManager()

    /// Cached — refreshed at startup and after requests (the underlying check
    /// is async).
    private(set) var notificationsAuthorized = false

    private init() {
        refreshNotificationStatus()
    }

    // MARK: - Notifications (reminders / focus breaks)

    func requestNotificationsIfNeeded() {
        guard !notificationsAuthorized else { return }
        requestNotifications()
    }

    func requestNotifications() {
        Task { [weak self] in
            _ = try? await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound])
            self?.refreshNotificationStatus()
        }
    }

    func refreshNotificationStatus() {
        Task { [weak self] in
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            self?.notificationsAuthorized = settings.authorizationStatus == .authorized
        }
    }

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
