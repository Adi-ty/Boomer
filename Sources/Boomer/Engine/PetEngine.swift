import Foundation
import Observation

/// The pet's "brain". Holds the current pet, needs/mood, and high-level state,
/// translates events/actions into state transitions, and persists everything
/// through `PetStore`. SwiftUI views observe it.
///
/// Concurrency: `@MainActor` (it drives UI). Monitors run elsewhere and hand work
/// in via the `EventBus`, which is drained on the main actor here. Geometry/physics
/// live in `PetMotion`, which reads this engine's `state` — the engine stays
/// free of window/screen concerns.
@MainActor
@Observable
final class PetEngine {
    /// Feeds/plays/pats needed before the second pet can be adopted.
    static let unlockThreshold = 10

    private(set) var pet: Pet
    private(set) var state: PetState = .idle
    private(set) var needs: Needs
    private(set) var carePoints: Int
    /// "Stay put" — `PetMotion` checks this to suppress wandering/zoomies.
    private(set) var calmMode: Bool
    /// True while the panel is temporarily hidden (menu state only).
    private(set) var isPetHidden = false
    /// Text the pet is currently "saying" in its speech bubble.
    private(set) var announcement: String?

    var mood: Mood {
        needs.mood
    }

    var hasOnboarded: Bool {
        store.state.hasCompletedOnboarding
    }

    var otherSpecies: PetSpecies {
        pet.species == .dog ? .cat : .dog
    }

    private let stateMachine = PetStateMachine()
    private let bus = EventBus()
    private let store: PetStore
    private var decayTask: Task<Void, Never>?
    private var eventTask: Task<Void, Never>?
    private var transientTask: Task<Void, Never>?
    @ObservationIgnored private var announcementTask: Task<Void, Never>?
    @ObservationIgnored private var lastCelebrationAt = Date.distantPast

    init(store: PetStore) {
        self.store = store
        let saved = store.state

        // The pet kept living while the app was quit: catch up on decay,
        // capped at two days so a vacation doesn't return a husk.
        var needs = saved.needs
        let elapsedSteps = Date().timeIntervalSince(saved.lastSaved) / 30
        let steps = min(max(elapsedSteps, 0), 5760)
        if steps > 1 { needs.applyDecay(steps: steps) }
        self.needs = needs

        carePoints = saved.carePoints
        calmMode = saved.calmMode
        pet = Pet(species: saved.activeSpecies,
                  name: saved.names[saved.activeSpecies.rawValue])
    }

    /// An engine for previews/snapshots, backed by a throwaway store.
    static func preview(species: PetSpecies) -> PetEngine {
        PetEngine(store: .ephemeral(species: species))
    }

    /// Begin the needs-decay loop and start draining the event bus.
    func start() {
        startDecayLoop()
        startEventLoop()
    }

    // MARK: - User actions

    func feed() {
        needs.feed()
        registerCare()
        enterTransient(.eating, for: 1.3)
    }

    func play() {
        needs.play()
        registerCare()
        enterTransient(.playing, for: 1.4)
    }

    /// Clicking/tapping the pet gives it a little attention.
    func pat() {
        needs.happiness = min(1, needs.happiness + 0.12)
        registerCare()
        enterTransient(.celebrating, for: 1.0)
    }

    func toggleSleep() {
        if state == .sleeping {
            request(.idle)
        } else {
            cancelTransient()
            request(.sleeping)
        }
        save()
    }

    func toggleCalmMode() {
        calmMode.toggle()
        save()
    }

    // MARK: - Speech & deliveries

    /// Show a speech bubble above the pet for a few seconds.
    func announce(_ text: String, for seconds: Double = 8) {
        announcementTask?.cancel()
        announcement = text
        announcementTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled else { return }
            self?.announcement = nil
        }
    }

    /// Celebrate, optionally saying something while doing it.
    func celebrate(saying text: String? = nil) {
        if let text { announce(text) }
        enterTransient(.celebrating, for: 2.5)
    }

    /// A reminder came due — the pet delivers it.
    func deliverReminder(_ title: String) {
        announce(title, for: 10)
        enterTransient(.celebrating, for: 2.0)
    }

    /// Focus session: nap quietly until the break.
    func beginFocusNap() {
        cancelTransient()
        request(.sleeping)
    }

    func endFocusNap() {
        if state == .sleeping { request(.idle) }
    }

    /// Bookkeeping for the menu while the AppDelegate hides/shows the panel.
    func setPetHidden(_ hidden: Bool) {
        isPetHidden = hidden
    }

    // MARK: - Pets & unlocking

    func isUnlocked(_ species: PetSpecies) -> Bool {
        store.state.unlocked.contains(species.rawValue)
    }

    func name(for species: PetSpecies) -> String {
        store.state.names[species.rawValue] ?? species.defaultName
    }

    /// Called when onboarding finishes with the chosen companion.
    func adopt(species: PetSpecies, name: String) {
        pet = Pet(species: species, name: name)
        cancelTransient()
        request(.idle)
        save()
    }

    /// Switch to an already-adopted pet.
    func switchTo(_ species: PetSpecies) {
        guard isUnlocked(species), species != pet.species else { return }
        pet = Pet(species: species, name: name(for: species))
        cancelTransient()
        request(.idle)
        save()
    }

    private func registerCare() {
        carePoints += 1
        if carePoints >= Self.unlockThreshold, !isUnlocked(otherSpecies) {
            var next = store.state
            next.unlocked.append(otherSpecies.rawValue)
            store.state = next
            enterTransient(.celebrating, for: 2.5) // adoption-day celebration
        }
        save()
    }

    // MARK: - External input

    /// Entry point for `boomer://` deep links — the bridge used by coding-agent
    /// integrations (Claude Code Stop hook, opencode plugin, …).
    func handleDeepLink(_ url: URL) {
        if url.host == "event", url.lastPathComponent == "agent-done" {
            let agent = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?
                .first { $0.name == "agent" }?
                .value ?? "unknown"
            bus.publish(.codingAgentCompleted(agent: agent))
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
            // Unzipping an archive can spray a dozen files into ~/Downloads;
            // one party every few seconds is plenty.
            guard Date().timeIntervalSince(lastCelebrationAt) > 3 else { return }
            lastCelebrationAt = Date()
            enterTransient(.celebrating, for: 2.0)
        default:
            request(stateMachine.next(for: event, current: state, needs: needs))
        }
    }

    #if DEBUG
        /// Snapshot-mode hook: pin an arbitrary expressive state.
        func debugForce(state newState: PetState) {
            request(newState)
        }
    #endif

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

    private func save() {
        var next = store.state
        next.activeSpecies = pet.species
        next.names[pet.species.rawValue] = pet.name
        next.carePoints = carePoints
        next.needs = needs
        next.calmMode = calmMode
        store.state = next
    }

    private func startDecayLoop() {
        decayTask?.cancel()
        decayTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                guard let self else { return }
                needs.decay()
                save()
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
