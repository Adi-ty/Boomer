import SwiftUI

/// Boomer is a macOS desktop pet. The app runs as a menu-bar agent (`LSUIElement`):
/// there is no main window — the pet lives in a floating panel managed by
/// `PetWindowController`, and the menu bar provides controls.
@main
struct BoomerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("Boomer", systemImage: "pawprint.fill") {
            MenuBarContent()
                .environment(appDelegate.engine)
        }
        .menuBarExtraStyle(.menu)
    }
}
