import Foundation

/// A pet instance. Lightweight value type for Phase 0; becomes a SwiftData
/// `@Model` in Phase 1 once persistence (stats, accessories, unlock state) lands.
struct Pet: Identifiable, Sendable, Equatable {
    let id: UUID
    var species: PetSpecies
    var name: String
    var isUnlocked: Bool

    init(id: UUID = UUID(), species: PetSpecies, name: String? = nil, isUnlocked: Bool = true) {
        self.id = id
        self.species = species
        self.name = name ?? species.defaultName
        self.isUnlocked = isUnlocked
    }

    /// Primary pet for a "dog person". The cat (Buttons) starts locked.
    static let boomer = Pet(species: .dog)
    static let buttons = Pet(species: .cat, isUnlocked: false)
}
