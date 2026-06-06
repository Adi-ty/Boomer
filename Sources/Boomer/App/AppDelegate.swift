import AppKit
import SwiftUI

/// Owns the long-lived objects: the pet "brain" (`PetEngine`) and the floating
/// pet window. SwiftUI instantiates this via `@NSApplicationDelegateAdaptor`.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let engine = PetEngine()
    private var petWindow: PetWindowController?

    func applicationDidFinishLaunching(_: Notification) {
        #if DEBUG
            if PetSnapshot.runIfRequested() {
                NSApp.terminate(nil)
                return
            }
        #endif
        petWindow = PetWindowController(engine: engine)
        petWindow?.show()
        engine.start()
    }

    /// Handles `boomer://…` deep links (e.g. the Claude Code Stop-hook bridge).
    /// Wired up fully in Phase 3; the scheme is already declared in Info.plist.
    func application(_: NSApplication, open urls: [URL]) {
        for url in urls where url.scheme == "boomer" {
            engine.handleDeepLink(url)
        }
    }
}
