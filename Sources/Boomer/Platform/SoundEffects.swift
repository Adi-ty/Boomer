import AppKit

/// What the pet can vocalize (mapped to bundled system sounds — subtle, short).
enum PetSound {
    case celebrate
    case munch
}

/// Plays the pet's sound effects. Gated by `PetEngine.soundsEnabled` before
/// reaching here.
@MainActor
enum SoundEffects {
    /// `NSSound.play()` is asynchronous and a deallocated sound goes silent —
    /// each instance must be kept alive until it finishes.
    private static var retained: [NSSound] = []

    static func play(_ sound: PetSound) {
        let name: NSSound.Name = switch sound {
        case .celebrate: "Glass"
        case .munch: "Pop"
        }
        // Copy: the named initializer can return a shared cached instance,
        // which refuses to restart while it's already playing.
        guard let template = NSSound(named: name),
              let instance = template.copy() as? NSSound else { return }
        instance.volume = 0.6
        retained.append(instance)
        instance.play()
        Task {
            try? await Task.sleep(for: .seconds(4))
            retained.removeAll { $0 === instance }
        }
    }
}
