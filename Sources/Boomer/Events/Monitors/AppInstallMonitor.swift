import Foundation

/// Celebrates new apps appearing in /Applications.
final class AppInstallMonitor: Sendable {
    private let folder: FolderMonitor

    init(bus: EventBus) {
        folder = FolderMonitor(url: URL(fileURLWithPath: "/Applications"), label: "applications") { added, _ in
            for bundle in added where bundle.hasSuffix(".app") && !bundle.hasPrefix(".") {
                bus.publish(.installCompleted(appName: String(bundle.dropLast(4))))
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
