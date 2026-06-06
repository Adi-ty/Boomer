import Foundation
import Observation

/// Pomodoro-style focus companion: the pet curls up and naps while you focus,
/// then wakes up and celebrates your break.
@MainActor
@Observable
final class FocusTimer {
    private(set) var endsAt: Date?

    var isActive: Bool {
        endsAt != nil
    }

    var remainingDescription: String {
        guard let endsAt else { return "" }
        let minutes = max(0, Int(endsAt.timeIntervalSinceNow.rounded()) / 60)
        return minutes >= 1 ? "\(minutes) min left" : "less than a minute"
    }

    private let engine: PetEngine
    @ObservationIgnored private var task: Task<Void, Never>?

    init(engine: PetEngine) {
        self.engine = engine
    }

    func start(minutes: Int) {
        endsAt = Date().addingTimeInterval(Double(minutes) * 60)
        engine.announce("Focus time — I'll nap. See you in \(minutes) minutes!", for: 5)
        engine.beginFocusNap()
        task?.cancel()
        task = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(5))
                guard let self, let endsAt else { return }
                if Date() >= endsAt {
                    complete()
                    return
                }
            }
        }
    }

    func cancel() {
        task?.cancel()
        endsAt = nil
        engine.endFocusNap()
    }

    private func complete() {
        endsAt = nil
        engine.endFocusNap()
        engine.celebrate(saying: "Break time! You earned it 🎉")
        ReminderScheduler.fireNow(title: "Focus session done — break time!")
    }
}
