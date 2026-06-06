import SwiftUI

/// Contents of the menu-bar dropdown. Most interaction happens by clicking and
/// dragging the pet itself; this is for the things you can't do by poking it.
struct MenuBarContent: View {
    @Environment(PetEngine.self) private var engine

    var body: some View {
        if engine.hasOnboarded {
            petMenu
        } else {
            Text("Boomer").font(.headline)
            Button("Finish setting up…") {
                NotificationCenter.default.post(name: .boomerShowOnboarding, object: nil)
            }
            Divider()
            quitButton
        }
    }

    @ViewBuilder
    private var petMenu: some View {
        Text("\(engine.pet.name) the \(engine.pet.species == .dog ? "dog" : "cat")")
            .font(.headline)
        Text("Mood: \(engine.mood.description)")

        Divider()

        Button("Feed") { engine.feed() }
        Button("Play") { engine.play() }
        Button(engine.state == .sleeping ? "Wake up" : "Take a nap") { engine.toggleSleep() }

        Divider()

        let other = engine.otherSpecies
        if engine.isUnlocked(other) {
            Button("Switch to \(engine.name(for: other))") { engine.switchTo(other) }
        } else {
            Button(
                "Adopt \(other.defaultName) — care \(min(engine.carePoints, PetEngine.unlockThreshold))/\(PetEngine.unlockThreshold)"
            ) {}
                .disabled(true)
        }

        Divider()

        quitButton
    }

    private var quitButton: some View {
        Button("Quit Boomer") { NSApplication.shared.terminate(nil) }
            .keyboardShortcut("q")
    }
}
