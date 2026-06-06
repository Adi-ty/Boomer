import SwiftUI

/// Contents of the menu-bar dropdown. Most interaction happens by clicking and
/// dragging the pet itself; this is for the things you can't do by poking it.
struct MenuBarContent: View {
    @Environment(PetEngine.self) private var engine

    var body: some View {
        Text("\(engine.pet.name) the \(engine.pet.species == .dog ? "dog" : "cat")")
            .font(.headline)
        Text("Mood: \(engine.mood.description)")

        Divider()

        Button("Feed") { engine.feed() }
        Button("Play") { engine.play() }
        Button(engine.state == .sleeping ? "Wake up" : "Take a nap") { engine.toggleSleep() }

        Divider()

        Button("Switch to \(engine.pet.species == .dog ? "Buttons (cat)" : "Boomer (dog)")") {
            engine.switchSpecies()
        }

        Divider()

        Button("Quit Boomer") { NSApplication.shared.terminate(nil) }
            .keyboardShortcut("q")
    }
}
