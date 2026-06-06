import AppKit
import SwiftData
import SwiftUI

/// Hosts the notes/reminders board in a small regular window.
@MainActor
final class BoardWindowController {
    private let window: NSWindow

    init(container: ModelContainer) {
        window = NSWindow(
            contentRect: NSRect(origin: .zero, size: DS.boardSize),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Notes & Reminders"
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: BoardView().modelContainer(container))
        window.center()
    }

    func show() {
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
}
