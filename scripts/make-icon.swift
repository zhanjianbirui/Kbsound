#!/usr/bin/env swift
// Renders Resources/AppIcon.icns from code, so the icon can be tweaked and re-rendered
// rather than living as an opaque binary blob.
//
// Everything is drawn once at 1024 pt and downsampled with high-quality interpolation;
// the shapes are deliberately bold so they survive the 16 pt size.
//
//     swift scripts/make-icon.swift
import AppKit

let canvas: CGFloat = 1024
// macOS app icon grid: the artwork sits in an 824 pt square inside the 1024 pt canvas.
let inset: CGFloat = 100
let side = canvas - inset * 2

/// Apple-style squircle (superellipse) rather than a circular-cornered rounded rect.
func squircle(in rect: CGRect, n: CGFloat = 5) -> NSBezierPath {
    let path = NSBezierPath()
    let a = rect.width / 2, b = rect.height / 2
    let cx = rect.midX, cy = rect.midY
    let steps = 720
    for step in 0...steps {
        let t = CGFloat(step) / CGFloat(steps) * 2 * .pi
        let c = cos(t), s = sin(t)
        let x = cx + a * (c < 0 ? -1 : 1) * pow(abs(c), 2 / n)
        let y = cy + b * (s < 0 ? -1 : 1) * pow(abs(s), 2 / n)
        step == 0 ? path.move(to: CGPoint(x: x, y: y)) : path.line(to: CGPoint(x: x, y: y))
    }
    path.close()
    return path
}

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

func drawIcon() {
    let body = CGRect(x: inset, y: inset, width: side, height: side)
    let shape = squircle(in: body)
    let ctx = NSGraphicsContext.current!.cgContext

    // Drop shadow, the way macOS icons carry one baked in.
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -14), blur: 18,
                  color: color(0x000000, 0.22).cgColor)
    color(0x000000).setFill()
    shape.fill()
    ctx.restoreGState()

    // Background: indigo → violet along the diagonal.
    ctx.saveGState()
    shape.addClip()
    NSGradient(colors: [color(0x7A6BFF), color(0x4B36C9), color(0x261A66)],
               atLocations: [0, 0.55, 1], colorSpace: .sRGB)?
        .draw(in: body, angle: -60)
    // Soft highlight in the top-left corner so the surface is not flat.
    let highlight = CGPoint(x: body.minX + side * 0.18, y: body.maxY - side * 0.12)
    NSGradient(colors: [color(0xFFFFFF, 0.22), color(0xFFFFFF, 0)], atLocations: [0, 1],
               colorSpace: .sRGB)?
        .draw(fromCenter: highlight, radius: 0,
              toCenter: highlight, radius: side * 0.5, options: [])
    ctx.restoreGState()

    // Sound waves on both sides of the keycap: symmetry reads better when tiny.
    let capSide: CGFloat = 372
    let cap = CGRect(x: (canvas - capSide) / 2, y: (canvas - capSide) / 2 - 14,
                     width: capSide, height: capSide)
    for (index, radius) in [CGFloat(116), 192].enumerated() {
        let width: CGFloat = index == 0 ? 34 : 28
        let alpha: CGFloat = index == 0 ? 0.95 : 0.62
        for direction in [-1.0, 1.0] as [CGFloat] {
            let center = CGPoint(x: cap.midX + direction * (capSide / 2 - 28), y: cap.midY + 10)
            let mid: CGFloat = direction > 0 ? 0 : 180
            let arc = NSBezierPath()
            arc.appendArc(withCenter: center, radius: radius,
                          startAngle: mid - 36, endAngle: mid + 36)
            arc.lineWidth = width
            arc.lineCapStyle = .round
            color(0xFFFFFF, alpha).setStroke()
            arc.stroke()
        }
    }

    // The keycap: the body is the visible front wall and sides, and the top face is
    // inset and lifted so the wall shows below it — that offset is what makes it read
    // as a key rather than a plain button.
    let bodyPath = NSBezierPath(roundedRect: cap, xRadius: 84, yRadius: 84)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -14), blur: 30,
                  color: color(0x160A3E, 0.6).cgColor)
    color(0xFFFFFF).setFill()
    bodyPath.fill()
    ctx.restoreGState()
    NSGradient(colors: [color(0xEFEDFA), color(0xA9A2CE)], atLocations: [0, 1],
               colorSpace: .sRGB)?.draw(in: bodyPath, angle: -90)

    let face = cap.insetBy(dx: 34, dy: 34).offsetBy(dx: 0, dy: 40)
    let facePath = NSBezierPath(roundedRect: face, xRadius: 58, yRadius: 58)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -6), blur: 12,
                  color: color(0x2A1C63, 0.3).cgColor)
    color(0xFFFFFF).setFill()
    facePath.fill()
    ctx.restoreGState()
    NSGradient(colors: [color(0xFFFFFF), color(0xF2F0FC)], atLocations: [0, 1],
               colorSpace: .sRGB)?.draw(in: facePath, angle: -90)
}

let master = NSImage(size: NSSize(width: canvas, height: canvas), flipped: false) { _ in
    drawIcon()
    return true
}

func png(size: CGFloat) -> Data {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size),
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: size, height: size)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSGraphicsContext.current?.imageInterpolation = .high
    master.draw(in: CGRect(x: 0, y: 0, width: size, height: size))
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let iconset = URL(filePath: "build/AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

for base in [16, 32, 128, 256, 512] {
    try png(size: CGFloat(base)).write(to: iconset.appending(path: "icon_\(base)x\(base).png"))
    try png(size: CGFloat(base * 2))
        .write(to: iconset.appending(path: "icon_\(base)x\(base)@2x.png"))
}

let task = Process()
task.executableURL = URL(filePath: "/usr/bin/iconutil")
task.arguments = ["-c", "icns", iconset.path, "-o", "Resources/AppIcon.icns"]
try task.run()
task.waitUntilExit()
guard task.terminationStatus == 0 else { exit(task.terminationStatus) }
print("==> Resources/AppIcon.icns")
