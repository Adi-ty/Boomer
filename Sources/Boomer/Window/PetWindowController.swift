import AppKit
import SwiftUI

/// Hosts the pet in a borderless, transparent, non-activating panel that floats
/// over every Space (including full-screen apps). The panel is moved around the
/// screen by `PetMotion`; mouse interaction is handled by `DraggablePetView`.
@MainActor
final class PetWindowController {
    static let size = NSSize(width: 200, height: 220)

    private let panel: NSPanel
    private let engine: PetEngine
    private let motion: PetMotion
    private let content: DraggablePetView

    init(engine: PetEngine) {
        self.engine = engine
        motion = PetMotion(engine: engine, size: Self.size)

        panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: Self.size),
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

        content = DraggablePetView(frame: NSRect(origin: .zero, size: Self.size))
        let host = NSHostingView(rootView: PetView(engine: engine, motion: motion))
        host.frame = content.bounds
        host.autoresizingMask = [.width, .height]
        content.addSubview(host)
        panel.contentView = content

        motion.moveHandler = { [weak panel] origin in panel?.setFrameOrigin(origin) }
        wireMouse()
    }

    func show() {
        panel.orderFrontRegardless()
        motion.start(at: dropInSpot())
    }

    /// A coding agent finished: hop onto the frontmost terminal window and
    /// celebrate from its top edge (the engine's celebration runs in parallel
    /// via the event bus). No-op without Accessibility or a terminal window.
    func celebrateAtFrontmostTerminal() {
        guard let frame = TerminalLocator.frontmostTerminalWindowFrame(),
              let primary = NSScreen.screens.first else { return }
        // AX coordinates are top-left-origin; convert the window's top edge
        // to AppKit's bottom-left-origin space.
        let landingY = primary.frame.height - frame.origin.y
        motion.visit(centerX: frame.midX, landingY: landingY, for: 9)
    }

    /// Start a little above the floor near center, so the pet drops in on launch.
    private func dropInSpot() -> CGPoint {
        guard let frame = NSScreen.main?.visibleFrame else { return .zero }
        return CGPoint(x: frame.midX - Self.size.width / 2, y: frame.minY + 180)
    }

    private func wireMouse() {
        content.onDragBegan = { [weak motion] in motion?.dragBegan() }
        content.onDragMoved = { [weak motion] origin, velocity in motion?.dragMoved(to: origin, velocity: velocity) }
        content.onDragEnded = { [weak motion] velocity in motion?.dragEnded(velocity: velocity) }
        content.onTap = { [weak motion] in motion?.tap() }
    }
}
