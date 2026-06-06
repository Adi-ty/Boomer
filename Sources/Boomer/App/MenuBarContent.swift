import SwiftUI

/// Contents of the menu-bar dropdown. Most interaction happens by clicking and
/// dragging the pet itself; this is for the things you can't do by poking it.
struct MenuBarContent: View {
    @Environment(PetEngine.self) private var engine
    @Environment(FocusTimer.self) private var focus

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

        Button("Notes & Reminders…") {
            NotificationCenter.default.post(name: .boomerShowBoard, object: nil)
        }

        if focus.isActive {
            Text("Focusing — \(focus.remainingDescription)")
            Button("End focus early") { focus.cancel() }
        } else {
            Menu("Start focus session") {
                Button("25 minutes") { focus.start(minutes: 25) }
                Button("50 minutes") { focus.start(minutes: 50) }
            }
        }

        Divider()

        // Stay-out-of-the-way controls.
        Button(engine.calmMode ? "Resume wandering" : "Stay put (calm mode)") {
            engine.toggleCalmMode()
        }
        if engine.isPetHidden {
            Button("Come back out") {
                NotificationCenter.default.post(name: .boomerShowPet, object: nil)
            }
        } else {
            Button("Hide for 30 minutes") {
                NotificationCenter.default.post(name: .boomerHidePet, object: nil)
            }
        }

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

        superpowers

        Divider()

        quitButton
    }

    /// Permission-gated features. Rows show a checkmark once granted; granting
    /// Input Monitoring may require relaunching Boomer (macOS applies it then).
    private var superpowers: some View {
        Menu("Superpowers") {
            let permissions = PermissionsManager.shared
            Button {
                permissions.requestAccessibility()
            } label: {
                Label("Sit on Terminal when agents finish (Accessibility)",
                      systemImage: permissions.hasAccessibility ? "checkmark.circle.fill" : "circle")
            }
            .disabled(permissions.hasAccessibility)

            Button {
                permissions.requestInputMonitoring()
            } label: {
                Label("Keep you company while typing (Input Monitoring)",
                      systemImage: permissions.hasInputMonitoring ? "checkmark.circle.fill" : "circle")
            }
            .disabled(permissions.hasInputMonitoring)

            Button {
                permissions.requestNotifications()
            } label: {
                Label("Deliver reminders & break alerts (Notifications)",
                      systemImage: permissions.notificationsAuthorized ? "checkmark.circle.fill" : "circle")
            }
            .disabled(permissions.notificationsAuthorized)

            Divider()

            Text("Boomer only ever sees activity and window positions — never what you type or what's on screen.")
        }
    }

    private var quitButton: some View {
        Button("Quit Boomer") { NSApplication.shared.terminate(nil) }
            .keyboardShortcut("q")
    }
}
