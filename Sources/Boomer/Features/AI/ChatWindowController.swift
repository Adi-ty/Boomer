import AppKit
import SwiftUI

/// Hosts the chat-with-your-pet window.
@MainActor
final class ChatWindowController {
    private let window: NSWindow

    init(ai: AIService, engine: PetEngine) {
        window = NSWindow(
            contentRect: NSRect(origin: .zero, size: DS.chatSize),
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
