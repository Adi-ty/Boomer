import Foundation

/// The two pets Boomer is modeled on: a dog named **Boomer** and a cat named
/// **Buttons**. Onboarding picks one as primary; the other is unlockable.
enum PetSpecies: String, CaseIterable, Codable {
    case dog
    case cat

    var defaultName: String {
        switch self {
        case .dog: "Boomer"
        case .cat: "Buttons"
        }
    }

    /// Name of the `.riv` file shipped for this species (wired up in Phase 1).
    var riveFileName: String {
        switch self {
        case .dog: "boomer"
        case .cat: "buttons"
        }
    }

    /// SF Symbol used as placeholder art until the Rive assets exist.
    var placeholderSymbol: String {
        switch self {
        case .dog: "dog.fill"
        case .cat: "cat.fill"
        }
    }
}
