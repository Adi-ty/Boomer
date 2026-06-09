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

    /// Where the on-disk store lives. Scoped to our own folder (the SwiftData
    /// default is a shared `Application Support/default.store`) so uninstalling
    /// is a single `rm -rf` and no other app's data is ever touched.
    static var storeFolder: URL {
        URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Library/Application Support/Boomer", isDirectory: true)
    }

    init(inMemory: Bool = false) throws {
        let schema = Schema([Note.self, Reminder.self])
        let configuration: ModelConfiguration
        if inMemory {
            configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        } else {
            let folder = Self.storeFolder
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            configuration = ModelConfiguration(schema: schema,
                                               url: folder.appendingPathComponent("Boomer.store"))
        }
        container = try ModelContainer(for: schema, configurations: [configuration])
    }

    /// Build a service that never silently disables notes/reminders. If the
    /// on-disk store can't be opened (corrupt, or written by an incompatible
    /// schema), move it aside so a clean one is created next time and retry;
    /// as a last resort fall back to in-memory so the board still works for the
    /// session instead of the menu item doing nothing forever.
    static func resilient() -> PersistenceService? {
        if let service = try? PersistenceService() { return service }
        archiveUnreadableStore()
        if let service = try? PersistenceService() { return service }
        return try? PersistenceService(inMemory: true)
    }

    /// Move an unreadable store out of the way (keeping a timestamped copy in
    /// case the user wants to recover it) so a fresh one can be created.
    private static func archiveUnreadableStore() {
        let fileManager = FileManager.default
        let folder = storeFolder
        let stamp = Int(Date().timeIntervalSince1970)
        // SwiftData/SQLite keeps companion -wal/-shm files; move them all.
        for suffix in ["", "-wal", "-shm"] {
            let url = folder.appendingPathComponent("Boomer.store\(suffix)")
            guard fileManager.fileExists(atPath: url.path) else { continue }
            let backup = folder.appendingPathComponent("Boomer.store.corrupt-\(stamp)\(suffix)")
            try? fileManager.moveItem(at: url, to: backup)
        }
    }
}
