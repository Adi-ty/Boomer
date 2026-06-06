import AppKit

/// The pet panel's content view. Captures mouse events directly (AppKit, using
/// global mouse location) so dragging the borderless window is smooth and we can
/// measure throw velocity — SwiftUI's `DragGesture` fights a window that moves
/// under the cursor. A click without movement is treated as a "pat".
@MainActor
final class DraggablePetView: NSView {
    var onDragBegan: (() -> Void)?
    /// New window origin + current velocity (screen points, y-up).
    var onDragMoved: ((CGPoint, CGVector) -> Void)?
    var onDragEnded: ((CGVector) -> Void)?
    var onTap: (() -> Void)?

    private var originAtMouseDown: CGPoint = .zero
    private var mouseDownLocation: CGPoint = .zero
    private var lastLocation: CGPoint = .zero
    private var lastMoveTime: TimeInterval = 0
    private var lastVelocity: CGVector = .zero
    private var didDrag = false

    /// Route mouse events here rather than to the hosted SwiftUI view — but
    /// only within the pet's body. Clicks in the window's transparent margins
    /// fall through to whatever is underneath, so the pet never steals a click
    /// it isn't visually occupying. (Thin tail tips are deliberately excluded.)
    override func hitTest(_ point: NSPoint) -> NSView? {
        petHitRegion.contains(point) ? self : nil
    }

    private var petHitRegion: NSRect {
        // The pet art occupies the bottom ~205pt; the headroom above is for
        // the speech bubble and stays click-through.
        NSRect(x: bounds.midX - 70, y: 0, width: 140, height: min(bounds.height, 205))
    }

    override var mouseDownCanMoveWindow: Bool {
        false
    }

    override func mouseDown(with _: NSEvent) {
        guard let window else { return }
        originAtMouseDown = window.frame.origin
        mouseDownLocation = NSEvent.mouseLocation
        lastLocation = mouseDownLocation
        lastMoveTime = ProcessInfo.processInfo.systemUptime
        lastVelocity = .zero
        didDrag = false
        onDragBegan?()
    }

    override func mouseDragged(with _: NSEvent) {
        let location = NSEvent.mouseLocation
        let total = CGVector(dx: location.x - mouseDownLocation.x, dy: location.y - mouseDownLocation.y)
        if abs(total.dx) + abs(total.dy) > 3 { didDrag = true }

        let now = ProcessInfo.processInfo.systemUptime
        let dt = max(now - lastMoveTime, 1.0 / 240.0)
        lastVelocity = CGVector(dx: (location.x - lastLocation.x) / dt,
                                dy: (location.y - lastLocation.y) / dt)
        lastLocation = location
        lastMoveTime = now

        let newOrigin = CGPoint(x: originAtMouseDown.x + total.dx,
                                y: originAtMouseDown.y + total.dy)
        onDragMoved?(newOrigin, lastVelocity)
    }

    override func mouseUp(with _: NSEvent) {
        if didDrag {
            onDragEnded?(lastVelocity)
        } else {
            onTap?()
        }
    }
}
