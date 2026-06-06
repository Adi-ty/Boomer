import Foundation

/// Watches one directory for membership changes using a GCD file-system source
/// and snapshot diffing (no per-file C callbacks). All mutable state is confined
/// to `queue`, hence `@unchecked Sendable`.
final class FolderMonitor: @unchecked Sendable {
    private let url: URL
    private let queue: DispatchQueue
    private let onChange: @Sendable (_ added: [String], _ removed: [String]) -> Void
    private var source: DispatchSourceFileSystemObject?
    private var known: Set<String> = []

    init(url: URL, label: String,
         onChange: @escaping @Sendable (_ added: [String], _ removed: [String]) -> Void)
    {
        self.url = url
        self.onChange = onChange
        queue = DispatchQueue(label: "boomer.folder.\(label)")
    }

    func start() {
        queue.async { [self] in
            guard source == nil else { return }
            let descriptor = open(url.path, O_EVTONLY)
            guard descriptor >= 0 else { return }
            known = list()
            let newSource = DispatchSource.makeFileSystemObjectSource(
                fileDescriptor: descriptor, eventMask: .write, queue: queue
            )
            newSource.setEventHandler { [weak self] in self?.diff() }
            newSource.setCancelHandler { close(descriptor) }
            newSource.resume()
            source = newSource
        }
    }

    func stop() {
        queue.async { [self] in
            source?.cancel()
            source = nil
        }
    }

    private func diff() {
        let current = list()
        let added = current.subtracting(known).sorted()
        let removed = known.subtracting(current).sorted()
        known = current
        if !added.isEmpty || !removed.isEmpty {
            onChange(added, removed)
        }
    }

    private func list() -> Set<String> {
        Set((try? FileManager.default.contentsOfDirectory(atPath: url.path)) ?? [])
    }
}
