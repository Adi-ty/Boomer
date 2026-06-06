import AppKit
import Foundation

/// Detects typing **activity only** — a keystroke rate, nothing else.
///
/// Privacy invariant: the event handler never inspects the event. No
/// characters, key codes, or modifiers are read, stored, or transmitted; we
/// count that *a* key went down and immediately discard the event. Preserve this.
///
/// Requires Input Monitoring permission (gated via `PermissionsManager`); until
/// granted, `startIfPermitted()` is a no-op and can be retried.
@MainActor
final class TypingMonitor {
    private let bus: EventBus
    private var monitor: Any?
    private var stopWatcher: Task<Void, Never>?

    private var lastKeystroke = Date.distantPast
    private var burstCount = 0
    private var isTyping = false

    /// Typing starts after this many keystrokes in quick succession…
    private let startThreshold = 3
    /// …and stops after this long without one.
    private let stopAfter: TimeInterval = 3

    var isRunning: Bool {
        monitor != nil
    }

    init(bus: EventBus) {
        self.bus = bus
    }

    func startIfPermitted() {
        guard monitor == nil, PermissionsManager.shared.hasInputMonitoring else { return }
        monitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] _ in
            // Deliberately ignoring the event payload — activity only.
            Task { @MainActor in self?.keystroke() }
        }
        guard monitor != nil else { return }
        startStopWatcher()
    }

    func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        stopWatcher?.cancel()
    }

    private func keystroke() {
        let now = Date()
        burstCount = now.timeIntervalSince(lastKeystroke) < 2 ? burstCount + 1 : 1
        lastKeystroke = now
        if !isTyping, burstCount >= startThreshold {
            isTyping = true
            bus.publish(.typingStarted)
        }
    }

    private func startStopWatcher() {
        stopWatcher?.cancel()
        stopWatcher = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard let self else { return }
                if isTyping, Date().timeIntervalSince(lastKeystroke) > stopAfter {
                    isTyping = false
                    burstCount = 0
                    bus.publish(.typingStopped)
                }
            }
        }
    }
}
