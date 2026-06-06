import SwiftUI

/// The pet's on-screen body — a hand-drawn dog (Boomer) or cat (Buttons) built
/// from SwiftUI shapes. Animation is driven by `TimelineView`, modulated by the
/// pet's expressive state (`PetEngine`) and locomotion (`PetMotion`).
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
        let pose = Pose(engine: engine, motion: motion, time: time)
        let palette = Palette(species: engine.pet.species)

        ZStack {
            shadow(pose)

            ZStack {
                tail(pose, palette)
                legs(pose, palette)
                torso(pose, palette)
                head(pose, palette)
            }
            .scaleEffect(x: pose.facing, y: 1)
            .offset(y: -pose.bob)

            effects(pose)
        }
        .frame(width: 200, height: 220)
    }

    // MARK: - Body parts

    private func shadow(_ pose: Pose) -> some View {
        Ellipse()
            .fill(.black.opacity(0.18 - pose.bob * 0.012))
            .frame(width: 116 - pose.bob, height: 18)
            .offset(y: 100)
    }

    private func tail(_ pose: Pose, _ palette: Palette) -> some View {
        Capsule()
            .fill(palette.bodyDark)
            .frame(width: 14, height: 40)
            .rotationEffect(.degrees(pose.tailAngle), anchor: .bottom)
            .offset(x: -46, y: 34)
    }

    private func legs(_ pose: Pose, _ palette: Palette) -> some View {
        ForEach(Array([-34.0, -14.0, 14.0, 34.0].enumerated()), id: \.offset) { index, baseX in
            Capsule()
                .fill(palette.bodyDark)
                .frame(width: 16, height: 30)
                .offset(x: baseX + (index.isMultiple(of: 2) ? pose.legSwing : -pose.legSwing), y: 78)
        }
    }

    private func torso(_ pose: Pose, _ palette: Palette) -> some View {
        ZStack {
            Ellipse()
                .fill(LinearGradient(colors: [palette.body, palette.bodyDark],
                                     startPoint: .top, endPoint: .bottom))
                .frame(width: 104, height: 80)
            Ellipse().fill(palette.belly).frame(width: 60, height: 50).offset(y: 12)
        }
        .scaleEffect(pose.breathe)
        .offset(y: 44)
    }

    private func head(_ pose: Pose, _ palette: Palette) -> some View {
        ZStack {
            ears(palette)
            Circle()
                .fill(LinearGradient(colors: [palette.body, palette.bodyDark.opacity(0.85)],
                                     startPoint: .top, endPoint: .bottom))
                .frame(width: 80, height: 80)
            face(pose, palette)
        }
        .scaleEffect(pose.breathe)
        .offset(y: -8)
    }

    @ViewBuilder
    private func ears(_ palette: Palette) -> some View {
        if engine.pet.species == .dog {
            ForEach([-1.0, 1.0], id: \.self) { side in
                Ellipse()
                    .fill(palette.bodyDark)
                    .frame(width: 26, height: 46)
                    .rotationEffect(.degrees(side * 20))
                    .offset(x: side * 32, y: -14)
            }
        } else {
            ForEach([-1.0, 1.0], id: \.self) { side in
                Triangle()
                    .fill(palette.body)
                    .frame(width: 30, height: 30)
                    .overlay(Triangle().fill(palette.inner).frame(width: 14, height: 13).offset(y: 5))
                    .offset(x: side * 24, y: -40)
            }
        }
    }

    private func face(_ pose: Pose, _ palette: Palette) -> some View {
        ZStack {
            if pose.blush {
                ForEach([-1.0, 1.0], id: \.self) { side in
                    Ellipse().fill(.pink.opacity(0.35)).frame(width: 16, height: 10).offset(x: side * 25, y: 9)
                }
            }
            ForEach([-1.0, 1.0], id: \.self) { side in
                eye(open: pose.eyeOpen).offset(x: side * 16, y: -10)
            }
            if engine.pet.species == .cat { whiskers() }
            nose(palette).offset(y: 4)
            mouth(pose, palette).offset(y: 17)
        }
        .frame(width: 80, height: 80)
    }

    private func eye(open: CGFloat) -> some View {
        ZStack {
            if open > 0.4 {
                Capsule().fill(.white).frame(width: 15, height: 18)
                Circle().fill(.black).frame(width: 9, height: 9).offset(y: 1)
                Circle().fill(.white).frame(width: 3, height: 3).offset(x: 2, y: -2)
            } else {
                Capsule().fill(.black.opacity(0.75)).frame(width: 15, height: 3)
            }
        }
    }

    @ViewBuilder
    private func nose(_ palette: Palette) -> some View {
        if engine.pet.species == .dog {
            Ellipse().fill(palette.nose).frame(width: 16, height: 12)
        } else {
            Triangle().fill(palette.nose).frame(width: 11, height: 8)
        }
    }

    private func whiskers() -> some View {
        ForEach([-1.0, 1.0], id: \.self) { side in
            ForEach(Array([-6.0, 6.0].enumerated()), id: \.offset) { index, deltaY in
                Capsule().fill(Color(white: 0.28).opacity(0.5))
                    .frame(width: 26, height: 1.5)
                    .rotationEffect(.degrees(side * (index == 0 ? -7 : 7)))
                    .offset(x: side * 40, y: 7 + deltaY)
            }
        }
    }

    @ViewBuilder
    private func mouth(_ pose: Pose, _ palette: Palette) -> some View {
        switch pose.mouth {
        case .open:
            ZStack {
                Ellipse().fill(.black.opacity(0.8)).frame(width: 22, height: 15)
                Ellipse().fill(palette.inner).frame(width: 13, height: 9).offset(y: 4)
            }
        case .smile:
            Smile().stroke(.black.opacity(0.7), style: .init(lineWidth: 2.4, lineCap: .round))
                .frame(width: 22, height: 12)
        case .neutral:
            Capsule().fill(.black.opacity(0.6)).frame(width: 14, height: 2.4)
        case .sleep:
            Smile().stroke(.black.opacity(0.5), style: .init(lineWidth: 2, lineCap: .round))
                .frame(width: 14, height: 7)
        }
    }

    @ViewBuilder
    private func effects(_ pose: Pose) -> some View {
        if pose.sleeping {
            Text("z z Z")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(.secondary)
                .offset(x: 42, y: -72)
        } else if pose.celebrating {
            ForEach(0 ..< 3, id: \.self) { index in
                Image(systemName: "sparkles")
                    .font(.system(size: 14))
                    .foregroundStyle(.yellow)
                    .offset(x: [-46, 42, 4][index], y: [-58, -48, -88][index])
            }
        }
    }
}

// MARK: - Pose (per-frame animation values)

private struct Pose {
    enum Mouth { case smile, open, neutral, sleep }

    let facing: CGFloat
    let bob: CGFloat
    let breathe: CGFloat
    let legSwing: CGFloat
    let tailAngle: Double
    let eyeOpen: CGFloat
    let mouth: Mouth
    let blush: Bool
    let sleeping: Bool
    let celebrating: Bool

    @MainActor
    init(engine: PetEngine, motion: PetMotion, time t: TimeInterval) {
        let state = engine.state
        let mood = engine.mood
        let walking = motion.activity == .walking
        let jumping = motion.activity == .falling
        sleeping = state == .sleeping
        celebrating = state == .celebrating || state == .playing
        let happy = mood == .happy || celebrating

        facing = motion.facing
        bob = walking ? abs(sin(t * 9)) * 5
            : celebrating ? abs(sin(t * 7)) * 6
            : sin(t * 2.0) * 1.2
        breathe = 1 + sin(t * (sleeping ? 1.2 : 2.2)) * (sleeping ? 0.035 : 0.02)
        legSwing = walking ? sin(t * 9) * 9 : (jumping ? 6 : 0)

        let wagSpeed = celebrating ? 16.0 : (happy ? 9.0 : 4.5)
        tailAngle = sin(t * wagSpeed) * (celebrating ? 28 : 16)

        if sleeping {
            eyeOpen = 0.05
        } else {
            eyeOpen = t.truncatingRemainder(dividingBy: 3.6) < 0.13 ? 0.08 : 1.0
        }

        switch state {
        case .sleeping: mouth = .sleep
        case .eating, .celebrating, .playing: mouth = .open
        default: mouth = (mood == .hungry || mood == .bored) ? .neutral : .smile
        }
        blush = happy
    }
}

// MARK: - Palette

private struct Palette {
    let body: Color
    let bodyDark: Color
    let belly: Color
    let nose: Color
    let inner: Color

    init(species: PetSpecies) {
        switch species {
        case .dog: // Boomer — warm golden retriever tones
            body = Color(red: 0.86, green: 0.64, blue: 0.40)
            bodyDark = Color(red: 0.63, green: 0.43, blue: 0.24)
            belly = Color(red: 0.97, green: 0.89, blue: 0.74)
            nose = Color(red: 0.17, green: 0.12, blue: 0.11)
            inner = Color(red: 0.95, green: 0.55, blue: 0.55)
        case .cat: // Buttons — soft grey tabby with a pink nose
            body = Color(red: 0.64, green: 0.66, blue: 0.71)
            bodyDark = Color(red: 0.44, green: 0.46, blue: 0.51)
            belly = Color(red: 0.95, green: 0.95, blue: 0.97)
            nose = Color(red: 0.92, green: 0.55, blue: 0.61)
            inner = Color(red: 0.95, green: 0.60, blue: 0.62)
        }
    }
}

// MARK: - Shapes

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

/// An upward-curving arc that reads as a smile (in SwiftUI's y-down space).
private struct Smile: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY),
                          control: CGPoint(x: rect.midX, y: rect.maxY * 1.6))
        return path
    }
}
