import Foundation

/// Pure logic for deciding which directory changes mean "a download finished".
/// Browsers stage files with temp extensions (`.crdownload`, `.download`,
/// `.part`, …) and rename them when done — the rename surfaces as the final
/// file appearing. Direct drops (curl, AirDrop, drag-in) also surface as new
/// non-temp files; celebrating those too is a feature.
enum DownloadDiff {
    static let tempExtensions: Set<String> = ["crdownload", "download", "part", "partial", "tmp"]

    static func completions(added: [String]) -> [String] {
        added.filter { name in
            !name.hasPrefix(".") && !isTemp(name)
        }
    }

    static func isTemp(_ name: String) -> Bool {
        tempExtensions.contains((name as NSString).pathExtension.lowercased())
    }
}

/// Celebrates files landing in ~/Downloads.
final class DownloadMonitor: Sendable {
    private let folder: FolderMonitor

    init(bus: EventBus) {
        let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Downloads")
        folder = FolderMonitor(url: downloads, label: "downloads") { added, _ in
            for file in DownloadDiff.completions(added: added) {
                bus.publish(.downloadCompleted(fileName: file))
            }
        }
    }

    func start() {
        folder.start()
    }

    func stop() {
        folder.stop()
    }
}
