#if DEBUG
    import AppKit
    import SwiftUI

    /// DEBUG-only: render the pet (and onboarding) in several states to PNGs,
    /// for development review without needing Screen Recording permission.
    /// Triggered by launching with the `BOOMER_SNAPSHOT=<dir>` environment
    /// variable; the app writes the images and exits. Never runs in normal use.
    @MainActor
    enum PetSnapshot {
        static func runIfRequested() -> Bool {
            guard let dir = ProcessInfo.processInfo.environment["BOOMER_SNAPSHOT"] else { return false }
            let folder = URL(fileURLWithPath: dir)
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

            renderPets(into: folder)
            renderOnboarding(into: folder)
            return true
        }

        private static func renderPets(into folder: URL) {
            let combos: [
                (name: String, species: PetSpecies, setup: (PetEngine) -> Void, activity: PetMotion.Activity)
            ] =
                [
                    ("dog-sit", .dog, { _ in }, .sitting),
                    ("dog-walk", .dog, { _ in }, .walking),
                    ("dog-run", .dog, { _ in }, .running),
                    ("dog-happy", .dog, { $0.pat() }, .sitting),
                    ("dog-eat", .dog, { $0.feed() }, .sitting),
                    ("dog-sleep", .dog, { $0.toggleSleep() }, .idle),
                    ("dog-typing", .dog, { $0.debugForce(state: .typing) }, .sitting),
                    ("dog-drag", .dog, { _ in }, .dragging),
                    ("cat-sit", .cat, { _ in }, .sitting),
                    ("cat-walk", .cat, { _ in }, .walking),
                    ("cat-run", .cat, { _ in }, .running),
                    ("cat-happy", .cat, { $0.pat() }, .sitting),
                    ("cat-sleep", .cat, { $0.toggleSleep() }, .idle),
                    ("cat-drag", .cat, { _ in }, .dragging),
                ]

            for combo in combos {
                let engine = PetEngine.preview(species: combo.species)
                combo.setup(engine)
                let motion = PetMotion(engine: engine, size: CGSize(width: 200, height: 220))
                motion.present(activity: combo.activity)
                let view = ZStack {
                    RoundedRectangle(cornerRadius: 18).fill(Color(white: 0.93))
                    PetView(engine: engine, motion: motion)
                }
                .frame(width: 200, height: 220)
                write(view, size: CGSize(width: 200, height: 220), to: folder, name: combo.name)
            }
        }

        private static func renderOnboarding(into folder: URL) {
            let steps: [(name: String, step: OnboardingView.Step, species: PetSpecies?)] = [
                ("onboarding-welcome", .welcome, nil),
                ("onboarding-choose", .choose, .dog),
                ("onboarding-name", .name, .cat),
            ]
            for item in steps {
                let view = OnboardingView(initialStep: item.step,
                                          preselected: item.species) { _, _ in }
                write(view, size: CGSize(width: 560, height: 600), to: folder, name: item.name)
            }
        }

        private static func write(_ view: some View, size: CGSize, to folder: URL, name: String) {
            let renderer = ImageRenderer(content: view.frame(width: size.width, height: size.height))
            renderer.scale = 2
            guard let image = renderer.nsImage,
                  let tiff = image.tiffRepresentation,
                  let rep = NSBitmapImageRep(data: tiff),
                  let png = rep.representation(using: .png, properties: [:])
            else { return }
            try? png.write(to: folder.appendingPathComponent("\(name).png"))
        }
    }
#endif
