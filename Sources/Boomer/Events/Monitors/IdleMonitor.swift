import CoreGraphics
import Foundation

/// Puts the pet to sleep when the user steps away and wakes it on return.
/// Uses `CGEventSource.secondsSinceLastEventType` (no permissions needed).
actor IdleMonitor {
    private let bus: EventBus
    private var loop: Task<Void, Never>?
    private var reportedIdle = false

    /// Asleep after this much inactivity.
    private let idleThreshold: TimeInterval = 240

    init(bus: EventBus) {
        self.bus = bus
    }

    func start() {
        loop?.cancel()
        loop = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(20))
                check()
            }
        }
    }

    func stop() {
        loop?.cancel()
    }

    private func check() {
        // There is no public "any input" event type; take the freshest of the
        // common ones.
        let types: [CGEventType] = [.keyDown, .mouseMoved, .leftMouseDown, .rightMouseDown, .scrollWheel]
        let idle = types
            .map { CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: $0) }
            .min() ?? 0

        if !reportedIdle, idle > idleThreshold {
            reportedIdle = true
            bus.publish(.userIdle)
        } else if reportedIdle, idle < 30 {
            reportedIdle = false
            bus.publish(.userActive)
        }
    }
}
