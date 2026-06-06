import AppKit

/// What the pet can vocalize (mapped to bundled system sounds — subtle, short).
enum PetSound {
    case celebrate
    case munch
}

/// Plays the pet's sound effects quietly. Gated by `PetEngine.soundsEnabled`
/// before reaching here.
@MainActor
enum SoundEffects {
    static func play(_ sound: PetSound) {
        let name: NSSound.Name = switch sound {
        case .celebrate: "Glass"
        case .munch: "Pop"
        }
        guard let instance = NSSound(named: name) else { return }
        instance.volume = 0.35
        instance.play()
    }
}
