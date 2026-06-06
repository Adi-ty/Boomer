import Foundation

/// The pet's overall disposition, derived from `Needs`.
enum Mood: String, CustomStringConvertible {
    case happy
    case content
    case bored
    case hungry
    case sleepy

    var description: String {
        rawValue.capitalized
    }
}

/// Tamagotchi-style needs that decay over time and drive `Mood`.
/// Each value is `0...1`, where `1` is fully satisfied.
struct Needs: Codable, Equatable {
    var hunger: Double = 0.8
    var happiness: Double = 0.8
    var energy: Double = 0.8

    var mood: Mood {
        if energy < 0.2 { return .sleepy }
        if hunger < 0.3 { return .hungry }
        if happiness < 0.3 { return .bored }
        if happiness > 0.7, hunger > 0.6 { return .happy }
        return .content
    }

    /// Called periodically by `PetEngine`'s decay timer.
    mutating func decay() {
        applyDecay(steps: 1)
    }

    /// Apply `steps` worth of decay at once — used to catch up on time the
    /// app spent quit (the pet kept living while you were away).
    mutating func applyDecay(steps: Double) {
        hunger = clamp(hunger - 0.02 * steps)
        happiness = clamp(happiness - 0.015 * steps)
        energy = clamp(energy - 0.01 * steps)
    }

    mutating func feed() {
        hunger = clamp(hunger + 0.4)
    }

    mutating func play() {
        happiness = clamp(happiness + 0.4)
        energy = clamp(energy - 0.1)
    }

    mutating func rest() {
        energy = clamp(energy + 0.5)
    }

    private func clamp(_ value: Double) -> Double {
        min(1, max(0, value))
    }
}
