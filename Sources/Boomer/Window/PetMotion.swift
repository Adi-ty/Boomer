import AppKit
import Observation

/// Drives where the pet *is* on screen: autonomous wandering (walk, sit, the
/// occasional zoomies), gravity, and grab-and-throw physics. Moves the pet's
/// window via `moveHandler`. The pet's *expression* (sleeping, celebrating, …)
/// lives in `PetEngine`; this reads it.
///
/// All coordinates are AppKit screen points (origin bottom-left, y increases up).
@MainActor
@Observable
final class PetMotion {
    enum Activity { case idle, sitting, walking, running, falling, dragging }

    private(set) var position: CGPoint = .zero
    private(set) var velocity: CGVector = .zero
    /// 1 = facing right, -1 = facing left. Drives the art's horizontal flip.
    private(set) var facing: Double = 1
    private(set) var activity: Activity = .idle
    /// True while airborne from a throw (used to show the dangling pose).
    private(set) var wasThrown = false

    /// Set by the window controller to reposition the pet's panel.
    @ObservationIgnored var moveHandler: ((CGPoint) -> Void)?

    private let engine: PetEngine
    private let size: CGSize
    @ObservationIgnored private var tickTask: Task<Void, Never>?
    @ObservationIgnored private var lastTime = Date()
    @ObservationIgnored private var lastSent = CGPoint(x: CGFloat.nan, y: CGFloat.nan)

    @ObservationIgnored private var nextDecision = Date()
    @ObservationIgnored private var walkTarget: CGFloat = 0
    @ObservationIgnored private var gaitSpeed: CGFloat = 85
    @ObservationIgnored private var wasCelebrating = false

    // Physics constants (points, points/s, points/s²).
    private let gravity: CGFloat = -2200
    private let walkSpeed: CGFloat = 85
    private let runSpeed: CGFloat = 300
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

    /// Pin a pose without running the simulation loop — used by snapshots and
    /// the onboarding preview cards.
    func present(activity newActivity: Activity, facing newFacing: Double = 1) {
        activity = newActivity
        facing = newFacing
    }

    // MARK: - Drag input (from DraggablePetView)

    func dragBegan() {
        activity = .dragging
        wasThrown = false
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
        wasThrown = true
        activity = .falling
    }

    /// A click (no drag) — the user patted the pet.
    func tap() {
        engine.pat()
        if isGrounded {
            velocity.dy = hopSpeed * 0.5
            activity = .falling
        }
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
            wasThrown = false
            activity = .falling
        }
        wasCelebrating = celebrating

        let sleeping = engine.state == .sleeping

        switch activity {
        case .dragging:
            break // position comes from drag callbacks
        case .falling:
            stepPhysics(dt)
        case .walking, .running:
            if sleeping { activity = .idle } else { stepGait(dt) }
        case .idle, .sitting:
            if !sleeping { decideNextMove(now) }
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
                wasThrown = false
                activity = .idle
                nextDecision = Date().addingTimeInterval(Double.random(in: 0.5 ... 1.5))
            }
        }
        if abs(velocity.dx) > 4 { facing = velocity.dx >= 0 ? 1 : -1 }
        position = next
    }

    private func stepGait(_ dt: TimeInterval) {
        let direction: CGFloat = walkTarget >= position.x ? 1 : -1
        facing = direction
        var next = position
        next.x += direction * gaitSpeed * CGFloat(dt)
        next.y = floorY
        let reached = (direction > 0 && next.x >= walkTarget) || (direction < 0 && next.x <= walkTarget)
        if reached {
            next.x = walkTarget
            // Often plop down into a sit after arriving somewhere.
            if Double.random(in: 0 ... 1) < 0.55 {
                activity = .sitting
                nextDecision = Date().addingTimeInterval(Double.random(in: 4 ... 9))
            } else {
                activity = .idle
                nextDecision = Date().addingTimeInterval(Double.random(in: 1 ... 2.5))
            }
        }
        position = CGPoint(x: min(max(next.x, minX), maxX), y: next.y)
    }

    private func decideNextMove(_ now: Date) {
        if position.y > floorY + 0.5 {
            activity = .falling // settle to ground
            return
        }
        guard now >= nextDecision else { return }

        let roll = Double.random(in: 0 ... 1)
        if activity == .sitting {
            // Stand up: usually go somewhere, sometimes just stand a moment.
            if roll < 0.75 { startGait(run: roll < 0.12) } else {
                activity = .idle
                nextDecision = now.addingTimeInterval(Double.random(in: 0.8 ... 2))
            }
        } else if roll < 0.40 {
            startGait(run: false)
        } else if roll < 0.52 {
            startGait(run: true) // zoomies!
        } else if roll < 0.85 {
            activity = .sitting
            nextDecision = now.addingTimeInterval(Double.random(in: 4 ... 9))
        } else {
            nextDecision = now.addingTimeInterval(Double.random(in: 1 ... 2.5))
        }
    }

    private func startGait(run: Bool) {
        let span = maxX - minX
        if run {
            // Dash to somewhere far across the screen.
            let target = position.x < minX + span / 2
                ? CGFloat.random(in: minX + span * 0.6 ... maxX)
                : CGFloat.random(in: minX ... minX + span * 0.4)
            walkTarget = target
            gaitSpeed = runSpeed
            activity = .running
        } else {
            walkTarget = CGFloat.random(in: minX ... max(minX, maxX))
            gaitSpeed = walkSpeed
            activity = .walking
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
