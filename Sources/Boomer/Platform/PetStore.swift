import Foundation

/// Everything Boomer remembers between launches. The data is tiny (one pet
/// family), so it lives as Codable JSON in UserDefaults; SwiftData arrives with
/// Notes in Phase 4.
struct PersistedState: Codable, Equatable {
    var hasCompletedOnboarding = false
    var activeSpecies: PetSpecies = .dog
    /// Custom names keyed by `PetSpecies` raw value.
    var names: [String: String] = [:]
    /// Species raw values the user has adopted.
    var unlocked: [String] = []
    /// Lifetime feeds/plays/pats — fills the second pet's adoption meter.
    var carePoints = 0
    var needs = Needs()
    /// When state was last written; used to decay needs for time spent away.
    var lastSaved = Date()
    /// "Stay put": no wandering/zoomies; the pet sits where it is.
    var calmMode = false

    init() {}

    /// Migration-safe decoding: every field falls back to its default when the
    /// key is missing, so adding fields never wipes an existing user's pet.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        hasCompletedOnboarding = try container
            .decodeIfPresent(Bool.self, forKey: .hasCompletedOnboarding) ?? false
        activeSpecies = try container
            .decodeIfPresent(PetSpecies.self, forKey: .activeSpecies) ?? .dog
        names = try container.decodeIfPresent([String: String].self, forKey: .names) ?? [:]
        unlocked = try container.decodeIfPresent([String].self, forKey: .unlocked) ?? []
        carePoints = try container.decodeIfPresent(Int.self, forKey: .carePoints) ?? 0
        needs = try container.decodeIfPresent(Needs.self, forKey: .needs) ?? Needs()
        lastSaved = try container.decodeIfPresent(Date.self, forKey: .lastSaved) ?? Date()
        calmMode = try container.decodeIfPresent(Bool.self, forKey: .calmMode) ?? false
    }
}

@MainActor
final class PetStore {
    static let storageKey = "boomer.state.v1"

    private let defaults: UserDefaults

    var state: PersistedState {
        didSet { persist() }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.storageKey),
           let decoded = try? JSONDecoder().decode(PersistedState.self, from: data)
        {
            state = decoded
        } else {
            state = PersistedState()
        }
    }

    /// A throwaway store for previews, snapshots, and tests.
    static func ephemeral(species: PetSpecies = .dog) -> PetStore {
        let suiteName = "boomer.ephemeral"
        let suite = UserDefaults(suiteName: suiteName) ?? .standard
        suite.removePersistentDomain(forName: suiteName)
        let store = PetStore(defaults: suite)
        store.state.activeSpecies = species
        store.state.unlocked = [species.rawValue]
        return store
    }

    func completeOnboarding(species: PetSpecies, name: String) {
        var next = state
        next.hasCompletedOnboarding = true
        next.activeSpecies = species
        next.unlocked = [species.rawValue]
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        next.names[species.rawValue] = trimmed.isEmpty ? species.defaultName : trimmed
        state = next
    }

    private func persist() {
        var copy = state
        copy.lastSaved = Date()
        guard let data = try? JSONEncoder().encode(copy) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }
}
