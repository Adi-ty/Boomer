import Foundation
import SwiftData

/// SwiftData container for record-style data (notes, reminders). Small
/// app-state (pet, needs, unlocks) stays in `PetStore`/UserDefaults.
@MainActor
final class PersistenceService {
    let container: ModelContainer

    var context: ModelContext {
        container.mainContext
    }

    init(inMemory: Bool = false) throws {
        let schema = Schema([Note.self, Reminder.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        container = try ModelContainer(for: schema, configurations: [configuration])
    }
}
