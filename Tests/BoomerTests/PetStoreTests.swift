import Foundation
import Testing
@testable import Boomer

@MainActor
struct PetStoreTests {
    private func freshDefaults() -> UserDefaults {
        let name = "boomer.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test func onboardingCompletionPersistsChoice() {
        let defaults = freshDefaults()
        let store = PetStore(defaults: defaults)
        store.completeOnboarding(species: .cat, name: "  Buttons Jr  ")

        // Reload from the same defaults to prove it round-trips.
        let reloaded = PetStore(defaults: defaults)
        #expect(reloaded.state.hasCompletedOnboarding)
        #expect(reloaded.state.activeSpecies == .cat)
        #expect(reloaded.state.names["cat"] == "Buttons Jr")
        #expect(reloaded.state.unlocked == ["cat"])
    }

    @Test func careUnlocksSecondPet() {
        let store = PetStore(defaults: freshDefaults())
        store.completeOnboarding(species: .dog, name: "Boomer")
        let engine = PetEngine(store: store)

        #expect(!engine.isUnlocked(.cat))
        for _ in 0 ..< PetEngine.unlockThreshold {
            engine.pat()
        }
        #expect(engine.isUnlocked(.cat))
        #expect(engine.state == .celebrating) // adoption-day celebration
    }

    @Test func switchIsGatedUntilUnlock() {
        let store = PetStore(defaults: freshDefaults())
        store.completeOnboarding(species: .dog, name: "Boomer")
        let engine = PetEngine(store: store)

        engine.switchTo(.cat)
        #expect(engine.pet.species == .dog) // still locked

        for _ in 0 ..< PetEngine.unlockThreshold {
            engine.pat()
        }
        engine.switchTo(.cat)
        #expect(engine.pet.species == .cat)
        #expect(engine.pet.name == "Buttons")
    }

    @Test func decodingStateWithoutNewerFieldsKeepsData() throws {
        // Simulate a save from an older build that predates `calmMode`.
        let json = """
        {"hasCompletedOnboarding": true, "activeSpecies": "cat",
         "names": {"cat": "Buttons"}, "unlocked": ["cat"], "carePoints": 4}
        """
        let state = try JSONDecoder().decode(PersistedState.self, from: Data(json.utf8))
        #expect(state.hasCompletedOnboarding)
        #expect(state.activeSpecies == .cat)
        #expect(state.carePoints == 4)
        #expect(state.calmMode == false)
        #expect(state.soundsEnabled == true)
    }

    @Test func awayTimeDecaysNeeds() throws {
        let defaults = freshDefaults()
        var stale = PersistedState()
        stale.hasCompletedOnboarding = true
        stale.lastSaved = Date(timeIntervalSinceNow: -3600) // away for an hour
        try defaults.set(JSONEncoder().encode(stale), forKey: PetStore.storageKey)

        let engine = PetEngine(store: PetStore(defaults: defaults))
        #expect(engine.needs.hunger < stale.needs.hunger)
        #expect(engine.needs.energy < stale.needs.energy)
    }
}
