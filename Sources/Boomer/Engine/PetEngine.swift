import Foundation
import Observation

/// The pet's "brain". Holds the current pet, needs/mood, and high-level state,
/// and translates events into state transitions. SwiftUI views observe it.
///
/// Concurrency: this is `@MainActor` (it drives UI). Monitors run elsewhere and
/// hand work in via the `EventBus`, which is drained on the main actor here.
@MainActor
@Observable
final class PetEngine {
    private(set) var pet: Pet
    private(set) var state: PetState = .idle
    private(set) var needs = Needs()

    var mood: Mood { needs.mood }

    private let stateMachine = PetStateMachine()
    private let bus = EventBus()
    private var decayTask: Task<Void, Never>?
    private var eventTask: Task<Void, Never>?

    init(pet: Pet = .boomer) {
        self.pet = pet
    }

    /// Begin the needs-decay loop and start draining the event bus.
    func start() {
        startDecayLoop()
        startEventLoop()
    }

    // MARK: - User actions

    func feed() {
        needs.feed()
        request(.eating)
    }

    func play() {
        needs.play()
        request(.playing)
    }

    // MARK: - External input

    /// Entry point for `boomer://` deep links (Stop-hook bridge, etc.). Phase 3
    /// fleshes out the routing; for now agent-done links trigger a celebration.
    func handleDeepLink(_ url: URL) {
        if url.host == "event", url.lastPathComponent == "agent-done" {
            bus.publish(.codingAgentCompleted(agent: "claude-code"))
        }
    }

    /// Exposed so monitors (Phase 3) can publish without holding the engine.
    nonisolated var eventSink: EventBus { bus }

    // MARK: - Internals

    private func handle(_ event: PetEvent) {
        request(stateMachine.next(for: event, current: state, needs: needs))
    }

    private func request(_ newState: PetState) {
        state = stateMachine.transition(from: state, to: newState)
        // Phase 1: push `state` into the active Rive state machine's inputs.
    }

    private func startDecayLoop() {
        decayTask?.cancel()
        decayTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                self?.needs.decay()
            }
        }
    }

    private func startEventLoop() {
        eventTask?.cancel()
        eventTask = Task { [weak self] in
            guard let stream = self?.bus.events else { return }
            for await event in stream {
                self?.handle(event)
            }
        }
    }
}
