import SwiftUI

/// How the body is arranged this frame (expression lives in `FaceParams`).
enum BodyPose { case sitting, standing, walking, running, curled, dangling }

/// The pet's on-screen body — an anime-styled dog (Boomer) or cat (Buttons)
/// drawn from SwiftUI shapes: chibi proportions, big layered eyes, fluff, and a
/// collar. Animation is driven by `TimelineView`, modulated by `PetEngine`
/// (expression) and `PetMotion` (pose/locomotion).
///
/// This is the renderer seam: a future phase can replace this view with a
/// Rive-backed one without touching the engine or motion.
struct PetView: View {
    let engine: PetEngine
    let motion: PetMotion

    var body: some View {
        TimelineView(.animation) { timeline in
            content(at: timeline.date.timeIntervalSinceReferenceDate)
        }
        .frame(width: 200, height: 220)
    }

    @ViewBuilder
    private func content(at time: TimeInterval) -> some View {
        let anim = Anim(engine: engine, motion: motion, time: time)
        let palette = Palette(species: anim.species)

        ZStack {
            groundShadow(anim)
            bodyView(anim, palette)
                .scaleEffect(x: anim.facing, y: 1)
                .offset(y: -anim.lift)
            effects(anim, palette)
        }
        .frame(width: 200, height: 220)
    }

    @ViewBuilder
    private func bodyView(_ anim: Anim, _ palette: Palette) -> some View {
        switch anim.pose {
        case .sitting: sittingBody(anim, palette)
        case .standing, .walking, .running: standingBody(anim, palette)
        case .curled: curledBody(anim, palette)
        case .dangling: danglingBody(anim, palette)
        }
    }

    private func headView(_ anim: Anim, _ palette: Palette) -> some View {
        PetHeadView(species: anim.species, palette: palette, face: anim.face)
    }

    // MARK: - Sitting (the hero pose)

    private func sittingBody(_ anim: Anim, _ palette: Palette) -> some View {
        ZStack {
            tailView(anim, palette, pose: .sitting)
            // haunches
            ForEach([-1.0, 1.0], id: \.self) { side in
                Ellipse()
                    .fill(side < 0 ? palette.shade : palette.body)
                    .frame(width: 42, height: 50)
                    .offset(x: side * 27, y: 72)
            }
            // pear-shaped torso
            Ellipse()
                .fill(LinearGradient(colors: [palette.body, palette.shade],
                                     startPoint: .top, endPoint: .bottom))
                .frame(width: 86, height: 98)
                .scaleEffect(anim.breathe)
                .offset(y: 50)
            Ellipse().fill(palette.belly).frame(width: 50, height: 66).offset(y: 60)
            chestFluff(anim, palette).offset(y: 26)
            // front legs + paws
            ForEach([-1.0, 1.0], id: \.self) { side in
                Capsule().fill(palette.body).frame(width: 15, height: 46).offset(x: side * 11, y: 73)
                Ellipse().fill(palette.belly).frame(width: 18, height: 11).offset(x: side * 11, y: 95)
            }
            collarView(anim, palette).offset(y: 8)
            headView(anim, palette).offset(y: -44)
        }
    }

    private func chestFluff(_ anim: Anim, _ palette: Palette) -> some View {
        // The dog gets a fuller retriever chest ruff.
        let positions: [Double] = anim.species == .dog ? [-22, -11, 0, 11, 22] : [-12, 0, 12]
        let size: CGFloat = anim.species == .dog ? 15 : 18
        return ForEach(Array(positions.enumerated()), id: \.offset) { index, x in
            Circle()
                .fill(palette.belly)
                .frame(width: size, height: size)
                .offset(x: x, y: index.isMultiple(of: 2) ? 0 : 6)
        }
    }

    // MARK: - Standing / walking / running

    private func standingBody(_ anim: Anim, _ palette: Palette) -> some View {
        ZStack {
            if anim.pose == .running { speedLines() }
            tailView(anim, palette, pose: anim.pose)
            // legs
            ForEach(Array([-36.0, -14.0, 16.0, 38.0].enumerated()), id: \.offset) { index, x in
                Capsule()
                    .fill(index.isMultiple(of: 2) ? palette.shade : palette.body)
                    .frame(width: 15, height: 36)
                    .offset(x: x + (index.isMultiple(of: 2) ? anim.legSwing : -anim.legSwing), y: 80)
            }
            // torso
            Ellipse()
                .fill(LinearGradient(colors: [palette.body, palette.shade],
                                     startPoint: .top, endPoint: .bottom))
                .frame(width: 110, height: 66)
                .scaleEffect(anim.breathe)
                .offset(y: 56)
            Ellipse().fill(palette.belly).frame(width: 70, height: 28).offset(y: 70)
            collarView(anim, palette).offset(x: 28, y: 30)
            headView(anim, palette).offset(x: 30, y: -26)
        }
        .rotationEffect(.degrees(anim.pose == .running ? -7 : 0))
    }

    private func speedLines() -> some View {
        Group {
            Capsule().fill(.white.opacity(0.5)).frame(width: 30, height: 4).offset(x: -78, y: 30)
            Capsule().fill(.white.opacity(0.55)).frame(width: 38, height: 4).offset(x: -84, y: 52)
            Capsule().fill(.white.opacity(0.45)).frame(width: 26, height: 4).offset(x: -74, y: 72)
        }
    }

    // MARK: - Curled up (sleeping)

    private func curledBody(_ anim: Anim, _ palette: Palette) -> some View {
        ZStack {
            Ellipse()
                .fill(LinearGradient(colors: [palette.body, palette.shade],
                                     startPoint: .top, endPoint: .bottom))
                .frame(width: 128, height: 70)
                .scaleEffect(anim.breathe)
                .offset(y: 64)
            if anim.species == .cat {
                // tail wrapped around the front
                Capsule()
                    .fill(palette.shade.opacity(0.85))
                    .frame(width: 92, height: 13)
                    .offset(x: -6, y: 92)
            } else {
                Ellipse().fill(palette.accent).frame(width: 30, height: 18).offset(x: -56, y: 80)
            }
            headView(anim, palette)
                .scaleEffect(0.82)
                .rotationEffect(.degrees(12))
                .offset(x: 22, y: 24)
        }
    }

    // MARK: - Dangling (grabbed or thrown)

    private func danglingBody(_ anim: Anim, _ palette: Palette) -> some View {
        ZStack {
            tailView(anim, palette, pose: .dangling)
            // stretched torso
            Ellipse()
                .fill(LinearGradient(colors: [palette.body, palette.shade],
                                     startPoint: .top, endPoint: .bottom))
                .frame(width: 66, height: 88)
                .offset(y: 42)
            Ellipse().fill(palette.belly).frame(width: 38, height: 54).offset(y: 46)
            // legs hanging loose
            ForEach(Array([-24.0, -9.0, 9.0, 24.0].enumerated()), id: \.offset) { index, x in
                Capsule()
                    .fill(index.isMultiple(of: 2) ? palette.shade : palette.body)
                    .frame(width: 13, height: 32)
                    .rotationEffect(.degrees(anim.dangleSway * (index.isMultiple(of: 2) ? 1 : -1)),
                                    anchor: .top)
                    .offset(x: x, y: 90)
            }
            collarView(anim, palette).offset(y: -2)
            headView(anim, palette).offset(y: -52)
        }
    }

    // MARK: - Tails

    @ViewBuilder
    private func tailView(_ anim: Anim, _ palette: Palette, pose: BodyPose) -> some View {
        if anim.species == .cat {
            switch pose {
            case .sitting:
                CatTailShape()
                    .stroke(palette.body, style: .init(lineWidth: 9, lineCap: .round))
                    .frame(width: 56, height: 92)
                    .rotationEffect(.degrees(anim.tailWag * 0.35), anchor: .bottomLeading)
                    .offset(x: 44, y: 36)
            case .standing, .walking:
                // Mirrored so the base (bottom-trailing) tucks into the rump and
                // the wag pivots around the attachment, not the tip.
                CatTailShape()
                    .stroke(palette.body, style: .init(lineWidth: 9, lineCap: .round))
                    .frame(width: 48, height: 78)
                    .scaleEffect(x: -1)
                    .rotationEffect(.degrees(anim.tailWag * 0.5), anchor: .bottomTrailing)
                    .offset(x: -60, y: 26)
            case .running:
                Capsule()
                    .fill(palette.body)
                    .frame(width: 52, height: 10)
                    .rotationEffect(.degrees(16))
                    .offset(x: -68, y: 48)
            case .dangling:
                Capsule()
                    .fill(palette.body)
                    .frame(width: 10, height: 44)
                    .rotationEffect(.degrees(anim.dangleSway), anchor: .top)
                    .offset(x: -32, y: 66)
            case .curled:
                EmptyView()
            }
        } else {
            switch pose {
            case .sitting:
                dogTailPlume(palette)
                    .rotationEffect(.degrees(anim.tailWag), anchor: .leading)
                    .offset(x: 42, y: 86)
            case .standing, .walking, .running:
                // Mirrored so the attachment (trailing) sits inside the torso
                // and the plume wags from its base.
                dogTailPlume(palette)
                    .scaleEffect(x: -1)
                    .rotationEffect(.degrees(22 - anim.tailWag), anchor: .trailing)
                    .offset(x: -50, y: 40)
            case .dangling:
                Ellipse().fill(palette.accent).frame(width: 14, height: 32).offset(x: -28, y: 66)
            case .curled:
                EmptyView()
            }
        }
    }

    // MARK: - Shared chrome

    /// A fluffy, feathered retriever tail (tip toward trailing edge).
    private func dogTailPlume(_ palette: Palette) -> some View {
        ZStack {
            Ellipse()
                .fill(palette.accent)
                .frame(width: 30, height: 11)
                .rotationEffect(.degrees(-16), anchor: .leading)
                .offset(x: 6, y: -4)
            Ellipse()
                .fill(palette.accent.opacity(0.92))
                .frame(width: 30, height: 11)
                .rotationEffect(.degrees(15), anchor: .leading)
                .offset(x: 6, y: 4)
            Ellipse()
                .fill(palette.accent)
                .frame(width: 42, height: 14)
        }
        .frame(width: 46, height: 18)
    }

    private func collarView(_ anim: Anim, _ palette: Palette) -> some View {
        ZStack {
            Capsule().fill(palette.collar).frame(width: 58, height: 11)
            if anim.species == .dog {
                Circle().fill(palette.charm).frame(width: 12, height: 12).offset(y: 9)
            } else {
                // Buttons gets a button.
                ZStack {
                    Circle().fill(palette.charm).frame(width: 11, height: 11)
                    Circle().stroke(palette.collar.opacity(0.55), lineWidth: 1).frame(width: 11, height: 11)
                    Circle().fill(palette.collar.opacity(0.7)).frame(width: 1.6, height: 1.6).offset(x: -1.8, y: -1.8)
                    Circle().fill(palette.collar.opacity(0.7)).frame(width: 1.6, height: 1.6).offset(x: 1.8, y: -1.8)
                    Circle().fill(palette.collar.opacity(0.7)).frame(width: 1.6, height: 1.6).offset(x: -1.8, y: 1.8)
                    Circle().fill(palette.collar.opacity(0.7)).frame(width: 1.6, height: 1.6).offset(x: 1.8, y: 1.8)
                }
                .offset(y: 9)
            }
        }
    }

    private func groundShadow(_ anim: Anim) -> some View {
        Ellipse()
            .fill(.black.opacity(max(0.06, 0.18 - anim.lift * 0.012)))
            .frame(width: max(70, (anim.pose == .curled ? 140 : 108) - anim.lift), height: 16)
            .offset(y: 102)
    }

    // MARK: - Effects overlay

    @ViewBuilder
    private func effects(_ anim: Anim, _ palette: Palette) -> some View {
        if anim.sleeping {
            Text("z z Z")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(.secondary)
                .offset(x: 48, y: -38)
        } else if anim.celebrating {
            Group {
                Image(systemName: "sparkles").font(.system(size: 15)).foregroundStyle(.yellow)
                    .offset(x: -50, y: -66)
                Image(systemName: "sparkles").font(.system(size: 12)).foregroundStyle(.yellow)
                    .offset(x: 46, y: -56)
                Image(systemName: "sparkles").font(.system(size: 13)).foregroundStyle(.yellow)
                    .offset(x: 2, y: -92)
            }
        }
        if anim.eating {
            snack(anim, palette).offset(x: anim.facing * 40, y: 34)
        }
    }

    @ViewBuilder
    private func snack(_ anim: Anim, _: Palette) -> some View {
        if anim.species == .dog {
            ZStack {
                Capsule().fill(.white).frame(width: 24, height: 7)
                Circle().fill(.white).frame(width: 9, height: 9).offset(x: -12, y: -3)
                Circle().fill(.white).frame(width: 9, height: 9).offset(x: -12, y: 3)
                Circle().fill(.white).frame(width: 9, height: 9).offset(x: 12, y: -3)
                Circle().fill(.white).frame(width: 9, height: 9).offset(x: 12, y: 3)
            }
            .shadow(color: .black.opacity(0.2), radius: 1, y: 1)
        } else {
            Image(systemName: "fish.fill")
                .font(.system(size: 18))
                .foregroundStyle(.teal)
        }
    }
}

// MARK: - Per-frame animation values

private struct Anim {
    let species: PetSpecies
    let pose: BodyPose
    let facing: CGFloat
    let lift: CGFloat
    let breathe: CGFloat
    let legSwing: CGFloat
    let tailWag: Double
    let dangleSway: Double
    let face: FaceParams
    let sleeping: Bool
    let celebrating: Bool
    let eating: Bool

    @MainActor
    init(engine: PetEngine, motion: PetMotion, time t: TimeInterval) {
        species = engine.pet.species
        let state = engine.state
        let mood = engine.mood
        let activity = motion.activity
        sleeping = state == .sleeping
        celebrating = state == .celebrating || state == .playing
        eating = state == .eating
        let typing = state == .typing
        let happy = mood == .happy || celebrating

        if sleeping {
            pose = .curled
        } else if activity == .dragging {
            pose = .dangling
        } else if activity == .falling {
            pose = motion.wasThrown ? .dangling : .standing
        } else if activity == .running {
            pose = .running
        } else if activity == .walking {
            pose = .walking
        } else if activity == .sitting || typing {
            pose = .sitting // typing buddy settles in and watches you work
        } else {
            pose = .standing
        }

        facing = motion.facing
        lift = switch pose {
        case .walking: abs(sin(t * 9)) * 4
        case .running: abs(sin(t * 13)) * 7
        default: celebrating ? abs(sin(t * 7)) * 5 : 0
        }
        breathe = 1 + sin(t * (sleeping ? 1.1 : 2.2)) * (sleeping ? 0.035 : 0.018)
        legSwing = switch pose {
        case .walking: sin(t * 9) * 8
        case .running: sin(t * 16) * 14
        default: 0
        }
        let wagSpeed = celebrating ? 15.0 : happy ? 8.0 : 4.0
        tailWag = sin(t * wagSpeed) * (celebrating ? 24 : 12)
        dangleSway = sin(t * 3.2) * 7

        var faceParams = FaceParams()
        faceParams.happyEyes = celebrating
        faceParams.surprised = pose == .dangling
        faceParams.blush = happy && !sleeping
        if sleeping {
            faceParams.eyeOpen = 0
            faceParams.mouth = .sleep
        } else {
            faceParams.eyeOpen = t.truncatingRemainder(dividingBy: 3.7) < 0.12 ? 0.1 : 1
            faceParams.mouth = (eating || celebrating) ? .open : (faceParams.surprised ? .oh : .tiny)
        }
        if pose == .sitting { faceParams.tilt = sin(t * 0.55) * 4 }
        faceParams.earTwitch = t.truncatingRemainder(dividingBy: 6.3) < 0.18
        faceParams.lookDown = typing && !sleeping
        face = faceParams
    }
}
