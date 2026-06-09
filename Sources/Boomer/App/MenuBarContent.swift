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
            Text("Boomer")
            Button("Finish setting up…") {
                NotificationCenter.default.post(name: .boomerShowOnboarding, object: nil)
            }
            Divider()
            quitButton
        }
    }

    // MARK: - Adopted-pet menu

    @ViewBuilder
    private var petMenu: some View {
        Text("\(engine.pet.species == .dog ? "🐶" : "🐱")  \(engine.pet.name) — \(engine.mood.description)")

        Divider()

        // Care.
        Button("Feed") { engine.feed() }
        Button("Play") { engine.play() }
        Button(engine.state == .sleeping ? "Wake up" : "Take a nap") { engine.toggleSleep() }

        Divider()

        // Things the pet helps with.
        Button("Notes & Reminders…") {
            NotificationCenter.default.post(name: .boomerShowBoard, object: nil)
        }
        Button("Chat with \(engine.pet.name)…") {
            NotificationCenter.default.post(name: .boomerShowChat, object: nil)
        }
        Button("Summarize clipboard") {
            NotificationCenter.default.post(name: .boomerSummarizeClipboard, object: nil)
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

        // Both pets are always available — switch whenever you like.
        let other = engine.otherSpecies
        Button("Switch to \(engine.name(for: other))") { engine.switchTo(other) }

        Divider()

        settings

        Divider()

        quitButton
    }

    // MARK: - Settings submenu

    private var settings: some View {
        Menu("Settings") {
            Button {
                engine.toggleSounds()
            } label: {
                Label("Sound effects",
                      systemImage: engine.soundsEnabled ? "checkmark.circle.fill" : "circle")
            }
            Button {
                LaunchAtLogin.shared.toggle()
            } label: {
                Label("Launch at login",
                      systemImage: LaunchAtLogin.shared.isEnabled ? "checkmark.circle.fill" : "circle")
            }
            Button {
                engine.toggleCalmMode()
            } label: {
                Label("Stay put (calm mode)",
                      systemImage: engine.calmMode ? "checkmark.circle.fill" : "circle")
            }

            Divider()

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

            permissions
        }
    }

    /// Permission-gated features. Rows show a checkmark once granted; granting
    /// Input Monitoring may require relaunching Boomer (macOS applies it then).
    private var permissions: some View {
        Menu("Permissions") {
            let perms = PermissionsManager.shared
            Button {
                perms.requestAccessibility()
            } label: {
                Label("Sit on Terminal when agents finish (Accessibility)",
                      systemImage: perms.hasAccessibility ? "checkmark.circle.fill" : "circle")
            }
            .disabled(perms.hasAccessibility)

            Button {
                perms.requestInputMonitoring()
            } label: {
                Label("Keep you company while typing (Input Monitoring)",
                      systemImage: perms.hasInputMonitoring ? "checkmark.circle.fill" : "circle")
            }
            .disabled(perms.hasInputMonitoring)

            Button {
                perms.requestNotifications()
            } label: {
                Label("Deliver reminders & break alerts (Notifications)",
                      systemImage: perms.notificationsAuthorized ? "checkmark.circle.fill" : "circle")
            }
            .disabled(perms.notificationsAuthorized)

            Divider()

            Text("Boomer only ever sees activity and window positions — never what you type or what's on screen.")
        }
    }

    private var quitButton: some View {
        Button("Quit Boomer") { NSApplication.shared.terminate(nil) }
            .keyboardShortcut("q")
    }
}
