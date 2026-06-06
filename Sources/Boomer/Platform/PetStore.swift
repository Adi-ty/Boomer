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
