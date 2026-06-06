#!/usr/bin/env swift
// Generates the Boomer app icon: a warm gradient rounded tile with a white
// paw print, rendered crisply at every required size and written into
// Sources/Boomer/Resources/Assets.xcassets/AppIcon.appiconset.
//
// Run via `make icon` (or directly: `swift scripts/make-boomer-icon.swift`).

import AppKit

let outDir = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "./Sources/Boomer/Resources/Assets.xcassets/AppIcon.appiconset"

try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

func render(px: CGFloat) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: Int(px), pixelsHigh: Int(px),
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    let s = px
    // macOS icon grid: rounded square inset slightly from the canvas.
    let inset = s * 0.05
    let tile = NSRect(x: inset, y: inset, width: s - inset * 2, height: s - inset * 2)
    let radius = tile.width * 0.225
    let tilePath = NSBezierPath(roundedRect: tile, xRadius: radius, yRadius: radius)

    // Warm golden gradient (Boomer's coat).
    let gradient = NSGradient(
        starting: NSColor(red: 1.00, green: 0.83, blue: 0.55, alpha: 1),
        ending: NSColor(red: 0.87, green: 0.55, blue: 0.22, alpha: 1)
    )!
    gradient.draw(in: tilePath, angle: -90)

    // Soft sheen fading down from the top edge (full-tile draw — a partial
    // rect leaves a visible hard band).
    let highlight = NSGradient(colors: [
        NSColor(white: 1, alpha: 0.30),
        NSColor(white: 1, alpha: 0.0),
        NSColor(white: 1, alpha: 0.0),
    ], atLocations: [0.0, 0.55, 1.0], colorSpace: .deviceRGB)!
    tilePath.addClip()
    highlight.draw(in: tile, angle: -90)

    // Paw print: main pad + four toes, white with a soft shadow.
    let shadow = NSShadow()
    shadow.shadowColor = NSColor(red: 0.45, green: 0.25, blue: 0.05, alpha: 0.35)
    shadow.shadowBlurRadius = s * 0.02
    shadow.shadowOffset = NSSize(width: 0, height: -s * 0.012)
    shadow.set()
    NSColor.white.setFill()

    let cx = s / 2
    // Main pad: a wide ellipse, slightly squashed, below center.
    let padW = s * 0.40, padH = s * 0.32
    let pad = NSBezierPath(ovalIn: NSRect(x: cx - padW / 2, y: s * 0.20, width: padW, height: padH))
    pad.fill()

    // Four toes fanned in an arc above the pad.
    let toeW = s * 0.145, toeH = s * 0.185
    let toes: [(dx: CGFloat, dy: CGFloat, tilt: CGFloat)] = [
        (-0.265, 0.50, 18), (-0.095, 0.585, 7), (0.095, 0.585, -7), (0.265, 0.50, -18),
    ]
    for toe in toes {
        let rect = NSRect(x: cx + s * toe.dx - toeW / 2, y: s * toe.dy, width: toeW, height: toeH)
        let path = NSBezierPath(ovalIn: rect)
        var transform = AffineTransform()
        transform.translate(x: rect.midX, y: rect.midY)
        transform.rotate(byDegrees: toe.tilt)
        transform.translate(x: -rect.midX, y: -rect.midY)
        path.transform(using: transform)
        path.fill()
    }

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

func write(px: CGFloat, name: String) {
    let rep = render(px: px)
    guard let png = rep.representation(using: .png, properties: [:]) else { return }
    try? png.write(to: URL(fileURLWithPath: "\(outDir)/\(name)"))
    print("  \(name) (\(Int(px))px)")
}

/// macOS icon set: 16/32/128/256/512 points at 1x and 2x.
let entries: [(pt: Int, scale: Int)] = [
    (16, 1), (16, 2), (32, 1), (32, 2), (128, 1), (128, 2), (256, 1), (256, 2), (512, 1), (512, 2),
]
print("Rendering AppIcon into \(outDir)")
var images: [String] = []
for entry in entries {
    let name = "icon_\(entry.pt)x\(entry.pt)\(entry.scale == 2 ? "@2x" : "").png"
    write(px: CGFloat(entry.pt * entry.scale), name: name)
    images.append("""
        {"filename": "\(name)", "idiom": "mac", "scale": "\(entry.scale)x", "size": "\(entry.pt)x\(entry.pt)"}
    """)
}

let contents = """
{
  "images": [
\(images.joined(separator: ",\n"))
  ],
  "info": {"author": "make-boomer-icon", "version": 1}
}
"""
try? contents.write(toFile: "\(outDir)/Contents.json", atomically: true, encoding: .utf8)
print("Done.")
