#if DEBUG
    import AppKit
    import SwiftUI

    /// DEBUG-only: render the pet in several states to PNGs, for development review
    /// without needing Screen Recording permission. Triggered by launching with the
    /// `BOOMER_SNAPSHOT=<dir>` environment variable; the app writes the images and
    /// exits. Never runs in normal use.
    @MainActor
    enum PetSnapshot {
        static func runIfRequested() -> Bool {
            guard let dir = ProcessInfo.processInfo.environment["BOOMER_SNAPSHOT"] else { return false }
            let folder = URL(fileURLWithPath: dir)
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

            let combos: [(name: String, species: PetSpecies, setup: (PetEngine) -> Void)] = [
                ("dog-idle", .dog, { _ in }),
                ("dog-happy", .dog, { $0.pat() }),
                ("dog-eat", .dog, { $0.feed() }),
                ("dog-sleep", .dog, { $0.toggleSleep() }),
                ("cat-idle", .cat, { _ in }),
                ("cat-happy", .cat, { $0.pat() }),
            ]

            for combo in combos {
                let engine = PetEngine(pet: Pet(species: combo.species))
                combo.setup(engine)
                let motion = PetMotion(engine: engine, size: CGSize(width: 200, height: 220))
                let view = ZStack {
                    RoundedRectangle(cornerRadius: 18).fill(Color(white: 0.93))
                    PetView(engine: engine, motion: motion)
                }
                .frame(width: 200, height: 220)

                let renderer = ImageRenderer(content: view)
                renderer.scale = 2
                guard let image = renderer.nsImage,
                      let tiff = image.tiffRepresentation,
                      let rep = NSBitmapImageRep(data: tiff),
                      let png = rep.representation(using: .png, properties: [:])
                else { continue }
                try? png.write(to: folder.appendingPathComponent("\(combo.name).png"))
            }
            return true
        }
    }
#endif
