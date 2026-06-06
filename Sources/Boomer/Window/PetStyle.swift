import SwiftUI

/// Colors for each species. The dog is a golden-retriever puppy (warm golds,
/// cream muzzle, glossy blue-grey eyes); the cat is a soft white anime cat with
/// big amber eyes (think Suzume's Daijin) and a red collar with a button charm —
/// she is called Buttons, after all.
struct Palette {
    let body: Color
    let shade: Color
    let accent: Color
    let belly: Color
    let nose: Color
    let innerEar: Color
    let irisInner: Color
    let irisOuter: Color
    let irisRim: Color
    let collar: Color
    let charm: Color

    init(species: PetSpecies) {
        switch species {
        case .dog:
            body = Color(red: 0.91, green: 0.72, blue: 0.45)
            shade = Color(red: 0.76, green: 0.55, blue: 0.29)
            accent = Color(red: 0.72, green: 0.51, blue: 0.26)
            belly = Color(red: 0.97, green: 0.90, blue: 0.72)
            nose = Color(red: 0.26, green: 0.18, blue: 0.15)
            innerEar = Color(red: 0.93, green: 0.71, blue: 0.54)
            irisInner = Color(red: 0.60, green: 0.68, blue: 0.86)
            irisOuter = Color(red: 0.28, green: 0.34, blue: 0.52)
            irisRim = Color(red: 0.14, green: 0.16, blue: 0.26)
            collar = Color(red: 0.26, green: 0.23, blue: 0.36)
            charm = Color(red: 0.95, green: 0.78, blue: 0.35)
        case .cat:
            body = Color(red: 0.97, green: 0.95, blue: 0.91)
            shade = Color(red: 0.86, green: 0.82, blue: 0.75)
            accent = Color(red: 0.91, green: 0.87, blue: 0.81)
            belly = Color.white
            nose = Color(red: 0.91, green: 0.58, blue: 0.62)
            innerEar = Color(red: 0.96, green: 0.73, blue: 0.77)
            irisInner = Color(red: 0.97, green: 0.81, blue: 0.42)
            irisOuter = Color(red: 0.83, green: 0.56, blue: 0.16)
            irisRim = Color(red: 0.42, green: 0.27, blue: 0.09)
            collar = Color(red: 0.79, green: 0.31, blue: 0.31)
            charm = Color(red: 0.94, green: 0.91, blue: 0.85)
        }
    }
}

// MARK: - Shapes

struct Triangle: Shape {
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
struct SmileArc: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY),
                          control: CGPoint(x: rect.midX, y: rect.maxY * 1.6))
        return path
    }
}

/// The closed "happy" anime eye: an arc curving upward like ⌒.
struct HappyArc: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.maxY),
                          control: CGPoint(x: rect.midX, y: rect.minY - rect.height * 0.3))
        return path
    }
}

/// A raised, gently curling cat tail (question-mark silhouette). Stroke it.
struct CatTailShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.18, y: rect.maxY))
        path.addCurve(
            to: CGPoint(x: rect.midX + rect.width * 0.22, y: rect.minY + rect.height * 0.28),
            control1: CGPoint(x: rect.minX, y: rect.maxY - rect.height * 0.45),
            control2: CGPoint(x: rect.maxX, y: rect.midY)
        )
        path.addQuadCurve(
            to: CGPoint(x: rect.midX - rect.width * 0.12, y: rect.minY + rect.height * 0.12),
            control: CGPoint(x: rect.midX + rect.width * 0.05, y: rect.minY - rect.height * 0.12)
        )
        return path
    }
}

/// The cat's tiny "ω" mouth: two small adjacent arcs.
struct CatMouth: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let midY = rect.minY
        path.move(to: CGPoint(x: rect.minX, y: midY))
        path.addQuadCurve(to: CGPoint(x: rect.midX, y: midY),
                          control: CGPoint(x: rect.width * 0.25, y: rect.maxY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: midY),
                          control: CGPoint(x: rect.width * 0.75, y: rect.maxY))
        return path
    }
}
