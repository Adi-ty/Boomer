import AppKit
import ApplicationServices

/// Finds the frontmost terminal-ish window so the pet can sit on it when a
/// coding agent finishes. Reads *window geometry only* via the Accessibility
/// API — never window contents. Requires Accessibility permission.
@MainActor
enum TerminalLocator {
    static let terminalBundleIDs: Set<String> = [
        "com.apple.Terminal",
        "com.googlecode.iterm2",
        "dev.warp.Warp-Stable",
        "com.github.wez.wezterm",
        "org.alacritty",
        "net.kovidgoyal.kitty",
        "com.mitchellh.ghostty",
        "com.microsoft.VSCode",
        "com.todesktop.230313mzl4w4u92", // Cursor
    ]

    /// The focused window frame of the frontmost terminal app, in AX coordinates
    /// (origin at the top-left of the primary display, y increasing downward).
    static func frontmostTerminalWindowFrame() -> CGRect? {
        guard PermissionsManager.shared.hasAccessibility else { return nil }
        for app in candidateApps() {
            if let frame = focusedWindowFrame(pid: app.processIdentifier) {
                return frame
            }
        }
        return nil
    }

    private static func candidateApps() -> [NSRunningApplication] {
        var seen = Set<pid_t>()
        var apps: [NSRunningApplication] = []
        let isTerminal: (NSRunningApplication) -> Bool = {
            $0.bundleIdentifier.map(terminalBundleIDs.contains) ?? false
        }
        if let front = NSWorkspace.shared.frontmostApplication, isTerminal(front) {
            apps.append(front)
            seen.insert(front.processIdentifier)
        }
        for app in NSWorkspace.shared.runningApplications
            where isTerminal(app) && seen.insert(app.processIdentifier).inserted
        {
            apps.append(app)
        }
        return apps
    }

    private static func focusedWindowFrame(pid: pid_t) -> CGRect? {
        let app = AXUIElementCreateApplication(pid)
        var windowRef: CFTypeRef?
        var window: AXUIElement?

        if AXUIElementCopyAttributeValue(app, kAXFocusedWindowAttribute as CFString, &windowRef) == .success,
           let ref = windowRef, CFGetTypeID(ref) == AXUIElementGetTypeID()
        {
            window = (ref as! AXUIElement)
        } else {
            var windowsRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &windowsRef) == .success,
               let windows = windowsRef as? [AXUIElement], let first = windows.first
            {
                window = first
            }
        }
        guard let window,
              let origin: CGPoint = axValue(
                  of: window,
                  attribute: kAXPositionAttribute,
                  type: .cgPoint,
                  initial: .zero
              ),
              let size: CGSize = axValue(of: window, attribute: kAXSizeAttribute, type: .cgSize, initial: .zero),
              size.width > 80, size.height > 60
        else { return nil }
        return CGRect(origin: origin, size: size)
    }

    private static func axValue<T>(of element: AXUIElement, attribute: String,
                                   type: AXValueType, initial: T) -> T?
    {
        var ref: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &ref) == .success,
              let ref, CFGetTypeID(ref) == AXValueGetTypeID()
        else { return nil }
        var out = initial
        guard AXValueGetValue(ref as! AXValue, type, &out) else { return nil }
        return out
    }
}
