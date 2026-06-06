import SwiftUI

/// Fixed palette for onboarding. The window forces light appearance, and every
/// piece of text uses these explicit inks — never adaptive system colors — so
/// the flow is readable regardless of the user's system theme.
private enum Theme {
    static let ink = Color(red: 0.24, green: 0.19, blue: 0.14) // warm near-black
    static let inkSoft = Color(red: 0.45, green: 0.40, blue: 0.34) // readable secondary
    static let bgTop = Color(red: 0.99, green: 0.96, blue: 0.89)
    static let bgBottom = Color(red: 0.86, green: 0.91, blue: 0.98)
    static let card = Color.white
    static let accent = Color.orange
}

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
    enum Step: Int, CaseIterable { case welcome, choose, name }

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
            LinearGradient(colors: [Theme.bgTop, Theme.bgBottom],
                           startPoint: .top, endPoint: .bottom)

            stepContent
                .id(step)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
        }
        .overlay(alignment: .topLeading) { backButton }
        .overlay(alignment: .bottom) { stepDots.padding(.bottom, 18) }
        .animation(.spring(duration: 0.35), value: step)
        .frame(width: 560, height: 620)
        .environment(\.colorScheme, .light) // controls match the fixed palette
    }

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case .welcome: welcome
        case .choose: choose
        case .name: naming
        }
    }

    // MARK: - Chrome

    @ViewBuilder
    private var backButton: some View {
        if step != .welcome {
            Button {
                step = step == .name ? .choose : .welcome
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.inkSoft)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(.white.opacity(0.75)))
            }
            .buttonStyle(.plain)
            .padding(.top, 40)
            .padding(.leading, 20)
            .help("Back")
        }
    }

    private var stepDots: some View {
        HStack(spacing: 8) {
            ForEach(Step.allCases, id: \.rawValue) { dot in
                Capsule()
                    .fill(dot == step ? Theme.accent : Theme.ink.opacity(0.18))
                    .frame(width: dot == step ? 22 : 8, height: 8)
            }
        }
    }

    // MARK: - Step 1: welcome

    private var welcome: some View {
        VStack(spacing: 0) {
            Spacer()

            // Both pets say hi.
            HStack(spacing: -8) {
                PetPreview(species: .dog).scaleEffect(0.78)
                PetPreview(species: .cat).scaleEffect(0.78)
            }
            .frame(height: 200)

            Text("Welcome to Boomer")
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.ink)
                .padding(.top, 18)

            Text(
                "A tiny companion who lives on your desktop —\nwanders around, naps, does zoomies,\nand celebrates your wins with you."
            )
            .font(.system(size: 16))
            .foregroundStyle(Theme.inkSoft)
            .multilineTextAlignment(.center)
            .lineSpacing(4)
            .padding(.top, 12)

            Spacer()

            Button {
                step = .choose
            } label: {
                Text("Say hello")
                    .font(.system(size: 16, weight: .semibold))
                    .padding(.horizontal, 26)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.accent)
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)

            Spacer().frame(height: 52)
        }
        .padding(.horizontal, 32)
    }

    // MARK: - Step 2: dog person or cat person

    private var choose: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 46)

            Text("Are you a dog person\nor a cat person?")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)
                .lineSpacing(2)

            Spacer()

            HStack(spacing: 22) {
                SpeciesCard(species: .dog, title: "Boomer", subtitle: "the dog",
                            isSelected: species == .dog) { select(.dog) }
                SpeciesCard(species: .cat, title: "Buttons", subtitle: "the cat",
                            isSelected: species == .cat) { select(.cat) }
            }

            Spacer()

            Text("Whichever you pick, care for them and you\ncan adopt the other one later. 🐾")
                .font(.system(size: 13))
                .foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)
                .lineSpacing(3)

            Button {
                petName = species?.defaultName ?? ""
                step = .name
            } label: {
                Text("Continue")
                    .font(.system(size: 16, weight: .semibold))
                    .padding(.horizontal, 26)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.accent)
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)
            .disabled(species == nil)
            .padding(.top, 14)

            Spacer().frame(height: 48)
        }
        .padding(.horizontal, 30)
    }

    private func select(_ pick: PetSpecies) {
        species = pick
        petName = pick.defaultName
    }

    // MARK: - Step 3: naming

    private var naming: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 36)

            if let species {
                PetPreview(species: species)

                Text("What should we call your \(species == .dog ? "dog" : "cat")?")
                    .font(.system(size: 27, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.ink)
                    .padding(.top, 4)

                TextField(species.defaultName, text: $petName)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 19, weight: .medium))
                    .multilineTextAlignment(.center)
                    .frame(width: 280)
                    .controlSize(.large)
                    .onSubmit(finish)
                    .padding(.top, 18)

                Text("\(species.defaultName) is a great name, just saying.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.inkSoft)
                    .padding(.top, 10)
            }

            Spacer()

            Button {
                finish()
            } label: {
                Text("Let \(petName.isEmpty ? "them" : petName) loose! 🎉")
                    .font(.system(size: 16, weight: .semibold))
                    .padding(.horizontal, 22)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.accent)
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)

            Spacer().frame(height: 52)
        }
        .padding(.horizontal, 30)
    }

    private func finish() {
        guard let species else { return }
        let trimmed = petName.trimmingCharacters(in: .whitespacesAndNewlines)
        onFinish(species, trimmed.isEmpty ? species.defaultName : trimmed)
    }
}

// MARK: - Species card

private struct SpeciesCard: View {
    let species: PetSpecies
    let title: String
    let subtitle: String
    let isSelected: Bool
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {
                PetPreview(species: species)
                    .scaleEffect(0.92)
                    .frame(width: 196, height: 204)

                Text(title)
                    .font(.system(size: 21, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.ink)
                Text(subtitle)
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.inkSoft)
                    .padding(.top, 1)
            }
            .padding(.top, 4)
            .padding(.bottom, 14)
            .padding(.horizontal, 10)
            .background(
                RoundedRectangle(cornerRadius: 22)
                    .fill(Theme.card.opacity(isSelected ? 0.95 : hovering ? 0.8 : 0.6))
                    .shadow(color: .black.opacity(isSelected || hovering ? 0.12 : 0.05),
                            radius: isSelected ? 10 : 5, y: 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .stroke(isSelected ? Theme.accent : .clear, lineWidth: 3)
            )
            .overlay(alignment: .topTrailing) {
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(.white, Theme.accent)
                        .padding(10)
                }
            }
            .scaleEffect(hovering && !isSelected ? 1.02 : 1)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(.spring(duration: 0.25), value: hovering)
        .animation(.spring(duration: 0.25), value: isSelected)
        .accessibilityLabel("\(title), \(subtitle)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
