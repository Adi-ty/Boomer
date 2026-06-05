import AppKit
import SwiftUI

/// Hosts the pet in a borderless, transparent, non-activating panel that floats
/// over every Space (including full-screen apps). Empty regions are click-through;
/// the pet sprite itself is interactive (drag + physics land in Phase 1).
@MainActor
final class PetWindowController {
    private let panel: NSPanel
    private let engine: PetEngine

    static let defaultSize = NSSize(width: 200, height: 200)

    init(engine: PetEngine) {
        self.engine = engine

        panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: Self.defaultSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        panel.isMovableByWindowBackground = false
        panel.hidesOnDeactivate = false

        let host = NSHostingView(rootView: RivePetView(engine: engine))
        host.autoresizingMask = [.width, .height]
        if let content = panel.contentView {
            host.frame = content.bounds
            content.addSubview(host)
        }
    }

    func show() {
        positionAtRestingSpot()
        panel.orderFrontRegardless()
    }

    /// Default resting spot: bottom-right of the main screen's visible area.
    private func positionAtRestingSpot() {
        guard let frame = NSScreen.main?.visibleFrame else { return }
        let origin = NSPoint(
            x: frame.maxX - Self.defaultSize.width - 24,
            y: frame.minY + 24
        )
        panel.setFrameOrigin(origin)
    }
}
