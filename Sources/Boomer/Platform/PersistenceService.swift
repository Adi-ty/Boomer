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
        let configuration: ModelConfiguration
        if inMemory {
            configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        } else {
            // Scope the store to our own folder (the SwiftData default is a
            // shared `Application Support/default.store`) so uninstalling is
            // a single `rm -rf` and no other app's data is ever touched.
            let folder = URL(fileURLWithPath: NSHomeDirectory())
                .appendingPathComponent("Library/Application Support/Boomer", isDirectory: true)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            configuration = ModelConfiguration(schema: schema,
                                               url: folder.appendingPathComponent("Boomer.store"))
        }
        container = try ModelContainer(for: schema, configurations: [configuration])
    }
}
