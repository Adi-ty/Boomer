import SwiftUI

/// Contents of the menu-bar dropdown. Kept intentionally small — most
/// interaction happens by clicking/dragging the pet itself.
struct MenuBarContent: View {
    @Environment(PetEngine.self) private var engine

    var body: some View {
        Text("\(engine.pet.name) — \(engine.mood.description)")
            .font(.headline)

        Button("Feed") { engine.feed() }
        Button("Play") { engine.play() }

        Divider()

        // Placeholders for features landing in later phases.
        Button("Notes…") {}.disabled(true)
        Button("Settings…") {}.disabled(true)

        Divider()

        Button("Quit Boomer") { NSApplication.shared.terminate(nil) }
            .keyboardShortcut("q")
    }
}
