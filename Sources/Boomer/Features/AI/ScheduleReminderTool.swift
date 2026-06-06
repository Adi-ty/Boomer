import Foundation
import FoundationModels

/// Lets the on-device model schedule *real* reminders when the user asks the
/// pet in chat ("remind me to stretch in 20 minutes").
struct ScheduleReminderTool: Tool {
    let name = "scheduleReminder"
    let description = "Schedule a reminder notification for the user after a number of minutes."

    /// Performs the actual scheduling (SwiftData insert + notification).
    let schedule: @Sendable @MainActor (_ title: String, _ minutes: Int) -> Void

    @Generable
    struct Arguments {
        @Guide(description: "Short reminder text, e.g. 'Call mom'")
        var title: String

        @Guide(description: "How many minutes from now the reminder should fire (1 to 720)")
        var minutes: Int
    }

    func call(arguments: Arguments) async throws -> String {
        // Clamp model-controlled values: bounded delay, bounded title length.
        let minutes = max(1, min(arguments.minutes, 12 * 60))
        let title = String(arguments.title.trimmingCharacters(in: .whitespacesAndNewlines).prefix(120))
        guard !title.isEmpty else {
            return "No reminder scheduled — the title was empty."
        }
        await MainActor.run { schedule(title, minutes) }
        return """
        Reminder '\(title)' scheduled successfully; it will fire in \(minutes) minutes. \
        Confirm to the user that you'll remind them about it in \(minutes) minutes — \
        it is NOT time for it yet, so don't announce it as happening now.
        """
    }
}
