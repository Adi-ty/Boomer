import AppKit
import SwiftUI

/// Hosts the chat-with-your-pet window.
@MainActor
final class ChatWindowController {
    private let window: NSWindow

    init(ai: AIService, engine: PetEngine) {
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 500),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Chat"
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: ChatView(ai: ai, engine: engine))
        window.center()
    }

    func show() {
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
}
