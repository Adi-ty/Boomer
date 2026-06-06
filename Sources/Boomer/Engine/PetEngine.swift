import Foundation
import Observation

/// The pet's "brain". Holds the current pet, needs/mood, and high-level state,
/// and translates events/actions into state transitions. SwiftUI views observe it.
///
/// Concurrency: `@MainActor` (it drives UI). Monitors run elsewhere and hand work
/// in via the `EventBus`, which is drained on the main actor here. Geometry/physics
/// live in `PetMotion`, which reads this engine's `state` — the engine stays
/// free of window/screen concerns.
@MainActor
@Observable
final class PetEngine {
    private(set) var pet: Pet
    private(set) var state: PetState = .idle
    private(set) var needs = Needs()

    var mood: Mood {
        needs.mood
    }

    private let stateMachine = PetStateMachine()
    private let bus = EventBus()
    private var decayTask: Task<Void, Never>?
    private var eventTask: Task<Void, Never>?
    private var transientTask: Task<Void, Never>?

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
        enterTransient(.eating, for: 1.3)
    }

    func play() {
        needs.play()
        enterTransient(.playing, for: 1.4)
    }

    /// Clicking/tapping the pet gives it a little attention.
    func pat() {
        needs.happiness = min(1, needs.happiness + 0.12)
        enterTransient(.celebrating, for: 1.0)
    }

    func toggleSleep() {
        if state == .sleeping {
            request(.idle)
        } else {
            cancelTransient()
            request(.sleeping)
        }
    }

    /// Preview the other pet (full multi-pet/unlock flow arrives in Phase 2).
    func switchSpecies() {
        pet = Pet(species: pet.species == .dog ? .cat : .dog)
        cancelTransient()
        request(.idle)
    }

    // MARK: - External input

    /// Entry point for `boomer://` deep links (Stop-hook bridge, etc.).
    func handleDeepLink(_ url: URL) {
        if url.host == "event", url.lastPathComponent == "agent-done" {
            bus.publish(.codingAgentCompleted(agent: "claude-code"))
        }
    }

    /// Exposed so monitors (Phase 3) can publish without holding the engine.
    nonisolated var eventSink: EventBus {
        bus
    }

    // MARK: - Internals

    private func handle(_ event: PetEvent) {
        switch event {
        case .downloadCompleted, .installCompleted, .codingAgentCompleted:
            enterTransient(.celebrating, for: 2.0)
        default:
            request(stateMachine.next(for: event, current: state, needs: needs))
        }
    }

    private func request(_ newState: PetState) {
        state = stateMachine.transition(from: state, to: newState)
    }

    /// Enter an expressive state that automatically returns to `.idle` after a
    /// beat (unless something else changes the state in the meantime).
    private func enterTransient(_ newState: PetState, for seconds: Double) {
        if state == .sleeping { request(.idle) }
        request(newState)
        cancelTransient()
        transientTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(seconds))
            guard let self, !Task.isCancelled else { return }
            if state == newState { request(.idle) }
        }
    }

    private func cancelTransient() {
        transientTask?.cancel()
        transientTask = nil
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
