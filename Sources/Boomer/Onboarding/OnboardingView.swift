import SwiftUI

/// Live, sitting pet used in the onboarding cards. Holders are cached so the
/// same engine/motion pair animates for the whole flow (and so ImageRenderer
/// snapshots see a populated view without needing async setup).
@MainActor
private enum PreviewZoo {
    private static var holders: [PetSpecies: (engine: PetEngine, motion: PetMotion)] = [:]

    static func holder(for species: PetSpecies) -> (engine: PetEngine, motion: PetMotion) {
        if let existing = holders[species] { return existing }
        let engine = PetEngine.preview(species: species)
        let motion = PetMotion(engine: engine, size: CGSize(width: 200, height: 220))
        motion.present(activity: .sitting)
        let pair = (engine, motion)
        holders[species] = pair
        return pair
    }
}

struct PetPreview: View {
    let species: PetSpecies

    var body: some View {
        let pair = PreviewZoo.holder(for: species)
        PetView(engine: pair.engine, motion: pair.motion)
            .frame(width: 200, height: 220)
    }
}

/// First-run flow: welcome → dog person or cat person → name them → done.
struct OnboardingView: View {
    enum Step { case welcome, choose, name }

    let onFinish: (PetSpecies, String) -> Void

    @State private var step: Step
    @State private var species: PetSpecies?
    @State private var petName = ""

    init(initialStep: Step = .welcome,
         preselected: PetSpecies? = nil,
         onFinish: @escaping (PetSpecies, String) -> Void)
    {
        self.onFinish = onFinish
        _step = State(initialValue: initialStep)
        _species = State(initialValue: preselected)
        _petName = State(initialValue: preselected?.defaultName ?? "")
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.99, green: 0.96, blue: 0.90),
                                    Color(red: 0.87, green: 0.92, blue: 0.98)],
                           startPoint: .top, endPoint: .bottom)

            switch step {
            case .welcome: welcome
            case .choose: choose
            case .name: naming
            }
        }
        .frame(width: 560, height: 600)
    }

    // MARK: - Step 1: welcome

    private var welcome: some View {
        VStack(spacing: 18) {
            Spacer()
            Image(systemName: "pawprint.fill")
                .font(.system(size: 56))
                .foregroundStyle(.orange.gradient)
            Text("Welcome to Boomer")
                .font(.system(size: 34, weight: .bold, design: .rounded))
            Text(
                "A tiny companion who lives on your desktop —\nwanders around, naps, does zoomies, and\ncelebrates your wins with you."
            )
            .font(.title3)
            .multilineTextAlignment(.center)
            .foregroundStyle(.secondary)
            Spacer()
            Button("Say hello") { step = .choose }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
            Spacer().frame(height: 40)
        }
        .padding(32)
    }

    // MARK: - Step 2: dog person or cat person

    private var choose: some View {
        VStack(spacing: 16) {
            Spacer().frame(height: 12)
            Text("Are you a dog person\nor a cat person?")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)

            HStack(spacing: 24) {
                speciesCard(.dog, title: "Boomer", subtitle: "the dog")
                speciesCard(.cat, title: "Buttons", subtitle: "the cat")
            }

            Text("No pressure — care for your pet and you can adopt the other one later. 🐾")
                .font(.callout)
                .foregroundStyle(.secondary)

            Button("Continue") {
                petName = species?.defaultName ?? ""
                step = .name
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)
            .disabled(species == nil)

            Spacer().frame(height: 20)
        }
        .padding(28)
    }

    private func speciesCard(_ cardSpecies: PetSpecies, title: String, subtitle: String) -> some View {
        let isSelected = species == cardSpecies
        return Button {
            species = cardSpecies
        } label: {
            VStack(spacing: 2) {
                PetPreview(species: cardSpecies)
                    .scaleEffect(0.82)
                    .frame(width: 176, height: 190)
                Text(title)
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                Text(subtitle)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.white.opacity(isSelected ? 0.9 : 0.55))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(isSelected ? Color.orange : .clear, lineWidth: 3)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Step 3: naming

    private var naming: some View {
        VStack(spacing: 16) {
            Spacer().frame(height: 8)
            if let species {
                PetPreview(species: species)
                Text("What should we call your \(species == .dog ? "dog" : "cat")?")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                TextField(species.defaultName, text: $petName)
                    .textFieldStyle(.roundedBorder)
                    .font(.title3)
                    .frame(width: 240)
                    .multilineTextAlignment(.center)
                    .onSubmit(finish)
                Text("(\(species.defaultName) is a great name, just saying.)")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Let them loose!") { finish() }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
            Spacer().frame(height: 28)
        }
        .padding(28)
    }

    private func finish() {
        guard let species else { return }
        let trimmed = petName.trimmingCharacters(in: .whitespacesAndNewlines)
        onFinish(species, trimmed.isEmpty ? species.defaultName : trimmed)
    }
}
