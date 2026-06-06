import AppKit
import SwiftUI

/// Hosts the first-run flow in a regular (activating) window — the one time
/// this agent app behaves like a normal app.
@MainActor
final class OnboardingWindowController {
    private let window: NSWindow

    init(onFinish: @escaping (PetSpecies, String) -> Void) {
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 620),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        // The flow uses a fixed light palette; pin the window to light
        // appearance so dark mode can't render white-on-cream text.
        window.appearance = NSAppearance(named: .aqua)
        window.contentView = NSHostingView(rootView: OnboardingView(onFinish: onFinish))
        window.center()
    }

    func show() {
        NSApp.activate(ignoringOtherApps: true)
        window.center()
        window.makeKeyAndOrderFront(nil)
    }

    func close() {
        window.orderOut(nil)
    }
}
