import AppKit
import SwiftData
import SwiftUI
import UserNotifications

extension Notification.Name {
    /// Posted (e.g. from the menu) to re-open onboarding if it was dismissed.
    static let boomerShowOnboarding = Notification.Name("boomerShowOnboarding")
    /// Posted from the menu to hide the pet for a while / bring it back.
    static let boomerHidePet = Notification.Name("boomerHidePet")
    static let boomerShowPet = Notification.Name("boomerShowPet")
    /// Posted from the menu to open the notes/reminders board.
    static let boomerShowBoard = Notification.Name("boomerShowBoard")
    /// Posted from the menu to open the chat window / summarize the clipboard.
    static let boomerShowChat = Notification.Name("boomerShowChat")
    static let boomerSummarizeClipboard = Notification.Name("boomerSummarizeClipboard")
}

/// Owns the long-lived objects: the persistence store, the pet "brain"
/// (`PetEngine`), the floating pet window, and the first-run onboarding window.
/// SwiftUI instantiates this via `@NSApplicationDelegateAdaptor`.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let store: PetStore
    let engine: PetEngine
    let focus: FocusTimer
    private let persistence: PersistenceService?
    private var petWindow: PetWindowController?
    private var onboarding: OnboardingWindowController?
    private var monitors: MonitorCoordinator?
    private var board: BoardWindowController?
    private var ai: AIService?
    private var chat: ChatWindowController?

    override init() {
        store = PetStore()
        engine = PetEngine(store: store)
        focus = FocusTimer(engine: engine)
        persistence = try? PersistenceService()
        super.init()
    }

    func applicationDidFinishLaunching(_: Notification) {
        #if DEBUG
            if PetSnapshot.runIfRequested() {
                NSApp.terminate(nil)
                return
            }
        #endif

        engine.soundHandler = { SoundEffects.play($0) }

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
        NotificationCenter.default.addObserver(
            forName: .boomerHidePet, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.hidePet(for: 30 * 60) }
        }
        NotificationCenter.default.addObserver(
            forName: .boomerShowPet, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.showPetAgain() }
        }
        NotificationCenter.default.addObserver(
            forName: .boomerShowBoard, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.showBoard() }
        }
        NotificationCenter.default.addObserver(
            forName: .boomerShowChat, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.showChat() }
        }
        NotificationCenter.default.addObserver(
            forName: .boomerSummarizeClipboard, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.showChat()
                self?.ai?.summarizeClipboard()
            }
        }

        UNUserNotificationCenter.current().delegate = self
    }

    private func showChat() {
        if ai == nil {
            ai = AIService(engine: engine) { [weak self] title, minutes in
                self?.scheduleReminderFromAI(title: title, minutes: minutes)
            }
        }
        guard let ai else { return }
        if chat == nil {
            chat = ChatWindowController(ai: ai, engine: engine)
        }
        chat?.show()
    }

    /// The model's `scheduleReminder` tool landed here: create the real thing.
    private func scheduleReminderFromAI(title: String, minutes: Int) {
        PermissionsManager.shared.requestNotificationsIfNeeded()
        let reminder = Reminder(title: title, dueDate: Date().addingTimeInterval(Double(minutes) * 60))
        persistence?.context.insert(reminder)
        ReminderScheduler.schedule(title: title, at: reminder.dueDate, id: reminder.notificationID)
    }

    private func showBoard() {
        guard let persistence else { return }
        if board == nil {
            board = BoardWindowController(container: persistence.container)
        }
        board?.show()
    }

    /// A scheduled notification fired while we're running: the pet delivers it
    /// in person too (unless the sweep already did) and the record is marked.
    private func notificationFired(id: String, body: String) {
        guard let context = persistence?.context else { return }
        let descriptor = FetchDescriptor<Reminder>(predicate: #Predicate { $0.notificationID == id })
        guard let match = try? context.fetch(descriptor).first, !match.isDelivered else { return }
        match.isDelivered = true
        engine.deliverReminder(body)
    }

    // MARK: - In-person reminder delivery

    private var reminderSweep: Task<Void, Never>?

    /// The pet itself is the primary reminder channel: system notifications
    /// silently no-op when permission was never granted, but the app is always
    /// running — so sweep for due reminders and have the pet deliver them.
    private func startReminderSweep() {
        reminderSweep?.cancel()
        reminderSweep = Task { [weak self] in
            while !Task.isCancelled {
                self?.deliverDueReminders()
                try? await Task.sleep(for: .seconds(20))
            }
        }
    }

    private func deliverDueReminders() {
        guard let context = persistence?.context else { return }
        let now = Date()
        let descriptor = FetchDescriptor<Reminder>(
            predicate: #Predicate { !$0.isDelivered && $0.dueDate <= now }
        )
        guard let due = try? context.fetch(descriptor), !due.isEmpty else { return }
        for reminder in due {
            reminder.isDelivered = true
            engine.deliverReminder(reminder.title)
        }
    }

    // MARK: - Temporary hide

    private var unhideTask: Task<Void, Never>?

    private func hidePet(for seconds: TimeInterval) {
        petWindow?.hidePanel()
        engine.setPetHidden(true)
        unhideTask?.cancel()
        unhideTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled else { return }
            self?.showPetAgain()
        }
    }

    private func showPetAgain() {
        unhideTask?.cancel()
        petWindow?.showPanel()
        engine.setPetHidden(false)
    }

    private var lastAgentVisit = Date.distantPast

    /// Handles `boomer://…` deep links (the Claude Code Stop-hook bridge).
    /// The engine celebrates via the event bus; the window layer additionally
    /// hops the pet onto the frontmost terminal when Accessibility allows.
    /// Deep links are unauthenticated local input — visits are rate-limited so
    /// a misbehaving page/process can't keep teleporting the pet around.
    func application(_: NSApplication, open urls: [URL]) {
        for url in urls where url.scheme == "boomer" {
            engine.handleDeepLink(url)
            if url.host == "event", url.lastPathComponent == "agent-done",
               Date().timeIntervalSince(lastAgentVisit) > 3
            {
                lastAgentVisit = Date()
                petWindow?.celebrateAtFrontmostTerminal()
            }
        }
    }

    // MARK: - Flow

    private func startPet() {
        guard petWindow == nil else { return }
        petWindow = PetWindowController(engine: engine)
        petWindow?.show()
        engine.start()
        monitors = MonitorCoordinator(bus: engine.eventSink)
        monitors?.start()
        startReminderSweep()
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

// MARK: - UNUserNotificationCenterDelegate

extension AppDelegate: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        let body = notification.request.content.body
        let id = notification.request.identifier
        await MainActor.run { self.notificationFired(id: id, body: body) }
        return [.banner, .sound]
    }
}
