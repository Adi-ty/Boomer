import SwiftUI

enum MouthKind { case tiny, open, oh, sleep }

/// Everything the face is doing this frame.
struct FaceParams {
    var eyeOpen: CGFloat = 1 // 0…1, squashes the eye when blinking
    var happyEyes = false // closed ⌒ ⌒ anime-happy eyes
    var surprised = false // smaller irises, wide look (dangling/thrown)
    var blush = false
    var mouth: MouthKind = .tiny
    var tilt: Double = 0 // gentle head tilt, degrees
    var earTwitch = false
}

/// The pet's head: big anime eyes, species ears, muzzle, whiskers, blush.
/// Drawn in a ~130pt box; the head circle is 100pt. Parents place it by offset.
struct PetHeadView: View {
    let species: PetSpecies
    let palette: Palette
    let face: FaceParams

    var body: some View {
        ZStack {
            ears
            headBase
            if species == .cat { cheekTufts }
            faceContent
        }
        .frame(width: 130, height: 130)
        .rotationEffect(.degrees(face.tilt))
    }

    // MARK: - Skull & ears

    private var headBase: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(colors: [palette.body, palette.shade.opacity(0.9)],
                                     startPoint: .top, endPoint: .bottom))
                .frame(width: 100, height: 100)
            // soft top-light so the face reads rounder
            Circle()
                .fill(RadialGradient(colors: [palette.belly.opacity(0.35), .clear],
                                     center: UnitPoint(x: 0.5, y: 0.3),
                                     startRadius: 4, endRadius: 60))
                .frame(width: 100, height: 100)
            if species == .dog { topTuft }
        }
        .offset(y: 8)
    }

    /// Fluffy fur bumps on the dog's crown (puppy bangs).
    private var topTuft: some View {
        ForEach(Array([-21.0, -7.0, 7.0, 21.0].enumerated()), id: \.offset) { index, x in
            Ellipse()
                .fill(palette.body)
                .frame(width: 25, height: 19)
                .offset(x: x, y: -47 + (index == 1 || index == 2 ? -6 : 0))
        }
    }

    @ViewBuilder
    private var ears: some View {
        if species == .dog {
            // Floppy puppy ears: tops tucked behind the skull, hanging down
            // beside the cheeks.
            ForEach([-1.0, 1.0], id: \.self) { side in
                Ellipse()
                    .fill(LinearGradient(colors: [palette.accent, palette.shade],
                                         startPoint: .top, endPoint: .bottom))
                    .frame(width: 30, height: 56)
                    .rotationEffect(.degrees(side * 12))
                    .offset(x: side * 46, y: 14)
            }
        } else {
            ForEach([-1.0, 1.0], id: \.self) { side in
                let twitch = face.earTwitch && side > 0 ? -9.0 : 0.0
                ZStack {
                    Triangle()
                        .fill(palette.body)
                        .frame(width: 36, height: 40)
                    Triangle()
                        .fill(palette.innerEar)
                        .frame(width: 18, height: 22)
                        .offset(y: 8)
                }
                .rotationEffect(.degrees(side * 14 + twitch))
                .offset(x: side * 28, y: -34)
            }
        }
    }

    /// Little fur spikes on the cat's cheeks.
    private var cheekTufts: some View {
        ForEach([-1.0, 1.0], id: \.self) { side in
            ForEach(Array([12.0, 26.0].enumerated()), id: \.offset) { _, y in
                Triangle()
                    .fill(palette.body)
                    .frame(width: 16, height: 14)
                    .rotationEffect(.degrees(side * -100))
                    .offset(x: side * 50, y: y)
            }
        }
    }

    // MARK: - Face

    private var faceContent: some View {
        ZStack {
            if face.blush {
                ForEach([-1.0, 1.0], id: \.self) { side in
                    Ellipse()
                        .fill(.pink.opacity(0.32))
                        .frame(width: 16, height: 9)
                        .offset(x: side * 36, y: 26)
                }
            }

            if species == .dog { brows }

            ForEach([-1.0, 1.0], id: \.self) { side in
                animeEye
                    .offset(x: side * (species == .cat ? 21 : 19), y: species == .cat ? 4 : 2)
            }

            if species == .cat { whiskers }

            muzzleAndMouth
        }
        .offset(y: 8)
    }

    /// Expressive little puppy brows.
    private var brows: some View {
        ForEach([-1.0, 1.0], id: \.self) { side in
            Capsule()
                .fill(palette.shade.opacity(0.85))
                .frame(width: 11, height: 3)
                .rotationEffect(.degrees(side * -12))
                .offset(x: side * 16, y: -22)
        }
    }

    private var whiskers: some View {
        ForEach([-1.0, 1.0], id: \.self) { side in
            ForEach(Array([-3.0, 6.0].enumerated()), id: \.offset) { index, deltaY in
                Capsule()
                    .fill(Color(white: 0.45).opacity(0.55))
                    .frame(width: 24, height: 1.5)
                    .rotationEffect(.degrees(side * (index == 0 ? -8 : 7)))
                    .offset(x: side * 52, y: 22 + deltaY)
            }
        }
    }

    // MARK: - Eyes

    private var eyeSize: CGSize {
        species == .cat ? CGSize(width: 30, height: 36) : CGSize(width: 26, height: 31)
    }

    @ViewBuilder
    private var animeEye: some View {
        let size = eyeSize
        if face.happyEyes {
            HappyArc()
                .stroke(palette.irisRim, style: .init(lineWidth: 3.4, lineCap: .round))
                .frame(width: size.width * 0.85, height: size.height * 0.34)
        } else if face.eyeOpen < 0.3 {
            Capsule()
                .fill(palette.irisRim.opacity(0.85))
                .frame(width: size.width * 0.8, height: 3)
        } else {
            openEye(size)
                .scaleEffect(y: face.eyeOpen, anchor: .center)
        }
    }

    private func openEye(_ size: CGSize) -> some View {
        let irisScale: CGFloat = face.surprised ? 0.82 : 1
        return ZStack {
            // iris: bright lower-center, deep at the edge — the anime glow
            Ellipse()
                .fill(RadialGradient(colors: [palette.irisInner, palette.irisOuter],
                                     center: UnitPoint(x: 0.5, y: 0.62),
                                     startRadius: 1, endRadius: size.height * 0.62))
            // upper-lid shadow
            Ellipse()
                .fill(palette.irisRim.opacity(0.45))
                .frame(width: size.width, height: size.height * 0.42)
                .offset(y: -size.height * 0.31)
                .blur(radius: 2)
            // pupil
            Ellipse()
                .fill(Color(red: 0.10, green: 0.07, blue: 0.05))
                .frame(width: size.width * 0.40, height: size.height * 0.50)
                .offset(y: size.height * 0.04)
            // glints
            Circle()
                .fill(.white.opacity(0.95))
                .frame(width: size.width * 0.30)
                .offset(x: -size.width * 0.17, y: -size.height * 0.20)
            Circle()
                .fill(.white.opacity(0.8))
                .frame(width: size.width * 0.12)
                .offset(x: size.width * 0.20, y: size.height * 0.18)
            Ellipse()
                .stroke(palette.irisRim, lineWidth: 2.2)
        }
        .frame(width: size.width, height: size.height)
        .scaleEffect(irisScale)
    }

    // MARK: - Muzzle & mouth

    @ViewBuilder
    private var muzzleAndMouth: some View {
        if species == .dog {
            Ellipse()
                .fill(palette.belly)
                .frame(width: 42, height: 30)
                .offset(y: 30)
            Ellipse()
                .fill(palette.nose)
                .frame(width: 18, height: 13)
                .offset(y: 21)
            mouthView.offset(y: 36)
        } else {
            Triangle()
                .fill(palette.nose)
                .frame(width: 10, height: 8)
                .rotationEffect(.degrees(180))
                .offset(y: 27)
            mouthView.offset(y: 35)
        }
    }

    @ViewBuilder
    private var mouthView: some View {
        switch face.mouth {
        case .tiny:
            if species == .cat {
                CatMouth()
                    .stroke(palette.irisRim.opacity(0.8), style: .init(lineWidth: 1.8, lineCap: .round))
                    .frame(width: 16, height: 6)
            } else {
                SmileArc()
                    .stroke(palette.nose.opacity(0.9), style: .init(lineWidth: 2.2, lineCap: .round))
                    .frame(width: 18, height: 6)
            }
        case .open:
            ZStack {
                Ellipse().fill(Color(red: 0.35, green: 0.13, blue: 0.13)).frame(width: 20, height: 15)
                Ellipse().fill(Color(red: 0.95, green: 0.55, blue: 0.55)).frame(width: 12, height: 8).offset(y: 4)
            }
        case .oh:
            Circle()
                .fill(Color(red: 0.35, green: 0.13, blue: 0.13))
                .frame(width: 9, height: 9)
        case .sleep:
            SmileArc()
                .stroke(palette.irisRim.opacity(0.5), style: .init(lineWidth: 1.8, lineCap: .round))
                .frame(width: 12, height: 5)
        }
    }
}
