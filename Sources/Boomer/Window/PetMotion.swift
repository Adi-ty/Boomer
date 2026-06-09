import AppKit
import CoreGraphics
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

    /// Temporary elevated "floor" (e.g. the top edge of a Terminal window).
    @ObservationIgnored private var floorOverride: CGFloat?
    @ObservationIgnored private var visitTask: Task<Void, Never>?

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
        startLoop()
    }

    func stop() {
        tickTask?.cancel()
        tickTask = nil
    }

    /// Restart the simulation where it left off (after a temporary hide).
    func resume() {
        guard tickTask == nil else { return }
        startLoop()
    }

    private func startLoop() {
        tickTask?.cancel()
        lastTime = Date()
        tickTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(16))
                self?.tick()
            }
        }
    }

    /// Pin a pose without running the simulation loop — used by snapshots and
    /// the onboarding preview cards.
    func present(activity newActivity: Activity, facing newFacing: Double = 1) {
        activity = newActivity
        facing = newFacing
    }

    // MARK: - Drag input (from DraggablePetView)

    func dragBegan() {
        endVisit() // grabbing the pet cancels any window perch
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

    /// Drop in on a specific spot (e.g. the top edge of a Terminal window),
    /// hang out there briefly, then head back to the desktop floor.
    func visit(centerX: CGFloat, landingY: CGFloat, for seconds: TimeInterval) {
        let maxLanding = (NSScreen.main?.visibleFrame.maxY ?? landingY) - size.height
        let landing = min(landingY, maxLanding)
        guard landing > screenFloor - 1 else { return }

        floorOverride = landing
        position = CGPoint(x: min(max(centerX - size.width / 2, minX), maxX), y: landing + 140)
        velocity = .zero
        wasThrown = false
        activity = .falling
        moveHandler?(position)
        lastSent = position

        visitTask?.cancel()
        visitTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(seconds))
            guard let self, !Task.isCancelled else { return }
            floorOverride = nil // next decision tick notices and glides home
        }
    }

    private func endVisit() {
        visitTask?.cancel()
        floorOverride = nil
    }

    // MARK: - Simulation

    /// The screen the pet is currently on, so the floor and roaming bounds
    /// follow it across displays instead of always using the main screen.
    private var currentScreen: NSScreen? {
        let probe = CGPoint(x: position.x + size.width / 2, y: position.y + 24)
        return NSScreen.screens.first { $0.frame.contains(probe) }
            ?? NSScreen.main
            ?? NSScreen.screens.first
    }

    /// The rectangle the pet may roam in. Normally this excludes the Dock and
    /// menu bar (`visibleFrame`); but on a full-screen Space those are hidden,
    /// so `visibleFrame` would still reserve their footprint and leave the pet
    /// resting in mid-air. Use the whole screen frame then.
    private var roamBounds: CGRect {
        guard let screen = currentScreen else {
            return CGRect(origin: .zero, size: size)
        }
        return screenChromeHidden ? screen.frame : screen.visibleFrame
    }

    private var screenFloor: CGFloat {
        roamBounds.minY
    }

    private var floorY: CGFloat {
        max(screenFloor, floorOverride ?? -.greatestFiniteMagnitude)
    }

    private var minX: CGFloat {
        roamBounds.minX
    }

    private var maxX: CGFloat {
        roamBounds.maxX - size.width
    }

    private var isGrounded: Bool {
        position.y <= floorY + 0.5 && abs(velocity.dy) < 1
    }

    // MARK: Full-screen detection

    @ObservationIgnored private var chromeHiddenCache = false
    @ObservationIgnored private var chromeCheckedAt = Date.distantPast

    /// True when a full-screen app covers the pet's screen (Dock + menu bar
    /// hidden). Sampled a few times a second — `CGWindowList` is cheap but not
    /// worth running on every 60 Hz frame.
    private var screenChromeHidden: Bool {
        let now = Date()
        if now.timeIntervalSince(chromeCheckedAt) > 0.4 {
            chromeCheckedAt = now
            chromeHiddenCache = fullScreenAppCoversScreen()
        }
        return chromeHiddenCache
    }

    /// Looks for a normal-layer window covering the pet's whole screen, including
    /// the menu-bar strip — the signature of macOS full-screen mode, as opposed
    /// to a merely maximized window (which stops at `visibleFrame`). Uses only
    /// window bounds + layer, so it needs no Screen Recording permission.
    private func fullScreenAppCoversScreen() -> Bool {
        guard let frame = currentScreen?.frame else { return false }
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let windows = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return false
        }
        for window in windows {
            guard let layer = window["kCGWindowLayer"] as? Int, layer == 0,
                  let boundsDict = window["kCGWindowBounds"] as? NSDictionary,
                  let rect = CGRect(dictionaryRepresentation: boundsDict as CFDictionary)
            else { continue }
            if rect.width >= frame.width - 1,
               rect.height >= frame.height - 1,
               abs(rect.minX - frame.minX) < 2
            {
                return true
            }
        }
        return false
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
            if reconcileFloor() { break }
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

    /// Keep a grounded pet glued to the (possibly just-changed) floor: drop to
    /// it if we're above it, snap up if the Dock/menu bar just reappeared
    /// beneath us (e.g. on leaving a full-screen app). Returns true if it
    /// adjusted, so the caller skips decision-making this tick.
    private func reconcileFloor() -> Bool {
        if position.y > floorY + 0.5 {
            activity = .falling
            return true
        }
        if position.y < floorY - 0.5 {
            position = CGPoint(x: position.x, y: floorY)
            return true
        }
        return false
    }

    private func decideNextMove(_ now: Date) {
        if floorOverride != nil {
            // Perched on a window: sit proudly, don't wander off the edge.
            if activity != .sitting { activity = .sitting }
            nextDecision = now.addingTimeInterval(1)
            return
        }
        if engine.calmMode {
            // "Stay put": settle into a sit and stay out of the way.
            if activity != .sitting { activity = .sitting }
            nextDecision = now.addingTimeInterval(1)
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
