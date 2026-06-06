import AppKit
import Observation

/// Drives where the pet *is* on screen: autonomous wandering, gravity, and
/// grab-and-throw physics. Moves the pet's window via `moveHandler`. The pet's
/// *expression* (sleeping, celebrating, …) lives in `PetEngine`; this reads it.
///
/// All coordinates are AppKit screen points (origin bottom-left, y increases up).
@MainActor
@Observable
final class PetMotion {
    enum Activity { case idle, walking, falling, dragging }

    private(set) var position: CGPoint = .zero
    private(set) var velocity: CGVector = .zero
    /// 1 = facing right, -1 = facing left. Drives the art's horizontal flip.
    private(set) var facing: Double = 1
    private(set) var activity: Activity = .idle

    /// Set by the window controller to reposition the pet's panel.
    @ObservationIgnored var moveHandler: ((CGPoint) -> Void)?

    private let engine: PetEngine
    private let size: CGSize
    @ObservationIgnored private var tickTask: Task<Void, Never>?
    @ObservationIgnored private var lastTime = Date()
    @ObservationIgnored private var lastSent = CGPoint(x: CGFloat.nan, y: CGFloat.nan)

    @ObservationIgnored private var nextDecision = Date()
    @ObservationIgnored private var walkTarget: CGFloat = 0
    @ObservationIgnored private var wasCelebrating = false

    // Physics constants (points, points/s, points/s²).
    private let gravity: CGFloat = -2200
    private let walkSpeed: CGFloat = 85
    private let restitution: CGFloat = 0.42
    private let hopSpeed: CGFloat = 700

    init(engine: PetEngine, size: CGSize) {
        self.engine = engine
        self.size = size
    }

    func start(at origin: CGPoint) {
        position = origin
        moveHandler?(origin)
        lastTime = Date()
        tickTask?.cancel()
        tickTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(16))
                self?.tick()
            }
        }
    }

    func stop() {
        tickTask?.cancel()
    }

    // MARK: - Drag input (from DraggablePetView)

    func dragBegan() {
        activity = .dragging
        velocity = .zero
    }

    func dragMoved(to origin: CGPoint, velocity newVelocity: CGVector) {
        position = clampedX(origin)
        velocity = newVelocity
        if abs(newVelocity.dx) > 6 { facing = newVelocity.dx >= 0 ? 1 : -1 }
        moveHandler?(position)
        lastSent = position
    }

    func dragEnded(velocity newVelocity: CGVector) {
        velocity = newVelocity
        activity = .falling
    }

    /// A click (no drag) — the user patted the pet.
    func tap() {
        engine.pat()
        if isGrounded { velocity.dy = hopSpeed * 0.5; activity = .falling }
    }

    // MARK: - Simulation

    private var floorY: CGFloat {
        NSScreen.main?.visibleFrame.minY ?? 0
    }

    private var minX: CGFloat {
        NSScreen.main?.visibleFrame.minX ?? 0
    }

    private var maxX: CGFloat {
        (NSScreen.main?.visibleFrame.maxX ?? size.width) - size.width
    }

    private var isGrounded: Bool {
        position.y <= floorY + 0.5 && abs(velocity.dy) < 1
    }

    private func tick() {
        let now = Date()
        let dt = min(now.timeIntervalSince(lastTime), 0.05)
        lastTime = now
        guard dt > 0 else { return }

        // Hop when a celebration begins.
        let celebrating = engine.state == .celebrating
        if celebrating, !wasCelebrating, isGrounded {
            velocity.dy = hopSpeed
            activity = .falling
        }
        wasCelebrating = celebrating

        let sleeping = engine.state == .sleeping

        switch activity {
        case .dragging:
            break // position comes from drag callbacks
        case .falling:
            stepPhysics(dt)
        case .walking:
            if sleeping { activity = .idle } else { stepWalk(dt) }
        case .idle:
            if !sleeping { wander(now) }
        }

        emitIfMoved()
    }

    private func stepPhysics(_ dt: TimeInterval) {
        velocity.dy += gravity * dt
        var next = position
        next.x += velocity.dx * dt
        next.y += velocity.dy * dt

        if next.x < minX { next.x = minX; velocity.dx = -velocity.dx * restitution }
        if next.x > maxX { next.x = maxX; velocity.dx = -velocity.dx * restitution }

        if next.y <= floorY {
            next.y = floorY
            if velocity.dy < -120 {
                velocity.dy = -velocity.dy * restitution // bounce
                velocity.dx *= 0.6
            } else {
                velocity = .zero
                activity = .idle
                nextDecision = Date().addingTimeInterval(Double.random(in: 0.6 ... 2.0))
            }
        }
        if abs(velocity.dx) > 4 { facing = velocity.dx >= 0 ? 1 : -1 }
        position = next
    }

    private func stepWalk(_ dt: TimeInterval) {
        let direction: CGFloat = walkTarget >= position.x ? 1 : -1
        facing = direction
        var next = position
        next.x += direction * walkSpeed * CGFloat(dt)
        next.y = floorY
        let reached = (direction > 0 && next.x >= walkTarget) || (direction < 0 && next.x <= walkTarget)
        if reached {
            next.x = walkTarget
            activity = .idle
            nextDecision = Date().addingTimeInterval(Double.random(in: 1.5 ... 4.5))
        }
        position = CGPoint(x: min(max(next.x, minX), maxX), y: next.y)
    }

    private func wander(_ now: Date) {
        if position.y > floorY + 0.5 { activity = .falling; return } // settle to ground
        guard now >= nextDecision else { return }
        if Double.random(in: 0 ... 1) < 0.6 {
            walkTarget = CGFloat.random(in: minX ... max(minX, maxX))
            activity = .walking
        } else {
            nextDecision = now.addingTimeInterval(Double.random(in: 2 ... 5))
        }
    }

    private func clampedX(_ point: CGPoint) -> CGPoint {
        CGPoint(x: min(max(point.x, minX), maxX), y: point.y)
    }

    private func emitIfMoved() {
        guard position != lastSent else { return }
        lastSent = position
        moveHandler?(position)
    }
}
