import AppKit
import SwiftUI

extension Notification.Name {
    /// Posted (e.g. from the menu) to re-open onboarding if it was dismissed.
    static let boomerShowOnboarding = Notification.Name("boomerShowOnboarding")
}

/// Owns the long-lived objects: the persistence store, the pet "brain"
/// (`PetEngine`), the floating pet window, and the first-run onboarding window.
/// SwiftUI instantiates this via `@NSApplicationDelegateAdaptor`.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let store: PetStore
    let engine: PetEngine
    private var petWindow: PetWindowController?
    private var onboarding: OnboardingWindowController?

    override init() {
        store = PetStore()
        engine = PetEngine(store: store)
        super.init()
    }

    func applicationDidFinishLaunching(_: Notification) {
        #if DEBUG
            if PetSnapshot.runIfRequested() {
                NSApp.terminate(nil)
                return
            }
        #endif

        if store.state.hasCompletedOnboarding {
            startPet()
        } else {
            showOnboarding()
        }

        NotificationCenter.default.addObserver(
            forName: .boomerShowOnboarding, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.showOnboarding() }
        }
    }

    /// Handles `boomer://…` deep links (e.g. the Claude Code Stop-hook bridge).
    /// Wired up fully in Phase 3; the scheme is already declared in Info.plist.
    func application(_: NSApplication, open urls: [URL]) {
        for url in urls where url.scheme == "boomer" {
            engine.handleDeepLink(url)
        }
    }

    // MARK: - Flow

    private func startPet() {
        guard petWindow == nil else { return }
        petWindow = PetWindowController(engine: engine)
        petWindow?.show()
        engine.start()
    }

    private func showOnboarding() {
        guard !store.state.hasCompletedOnboarding else { return }
        if onboarding == nil {
            onboarding = OnboardingWindowController { [weak self] species, name in
                guard let self else { return }
                store.completeOnboarding(species: species, name: name)
                engine.adopt(species: species, name: name)
                onboarding?.close()
                onboarding = nil
                startPet()
            }
        }
        onboarding?.show()
    }
}
