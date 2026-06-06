import Foundation

/// Owns all system monitors and their lifecycles. Created by the AppDelegate
/// once the pet is on screen; monitors publish onto the engine's `EventBus`.
@MainActor
final class MonitorCoordinator {
    private let downloads: DownloadMonitor
    private let installs: AppInstallMonitor
    private let idle: IdleMonitor
    private let typing: TypingMonitor
    private var permissionRetry: Task<Void, Never>?

    init(bus: EventBus) {
        downloads = DownloadMonitor(bus: bus)
        installs = AppInstallMonitor(bus: bus)
        idle = IdleMonitor(bus: bus)
        typing = TypingMonitor(bus: bus)
    }

    func start() {
        downloads.start()
        installs.start()
        Task { await idle.start() }
        typing.startIfPermitted()

        // Input Monitoring may be granted later (or mid-session from the menu);
        // keep retrying cheaply until the typing monitor is up.
        permissionRetry?.cancel()
        permissionRetry = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(20))
                guard let self else { return }
                typing.startIfPermitted()
                if typing.isRunning { return }
            }
        }
    }

    func stop() {
        downloads.stop()
        installs.stop()
        Task { await idle.stop() }
        typing.stop()
        permissionRetry?.cancel()
    }
}
