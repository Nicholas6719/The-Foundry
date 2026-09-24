// Generates the app icon and the menu bar template image with CoreGraphics.
// Run from the repo root:  swift scripts/make-icons.swift
import AppKit
import CoreGraphics
import Foundation

let bg = CGColor(srgbRed: 0x08 / 255, green: 0x12 / 255, blue: 0x0D / 255, alpha: 1)
let accent = CGColor(srgbRed: 0x62 / 255, green: 0xC4 / 255, blue: 0x7F / 255, alpha: 1)

/// Hexagon and arrowhead from the 48-point badge grid.
func hexagon(scale s: CGFloat, dx: CGFloat, dy: CGFloat) -> CGPath {
    let pts: [(CGFloat, CGFloat)] = [(24, 2), (43, 13), (43, 35), (24, 46), (5, 35), (5, 13)]
    let p = CGMutablePath()
    for (i, pt) in pts.enumerated() {
        let q = CGPoint(x: dx + pt.0 * s, y: dy + pt.1 * s)
        if i == 0 { p.move(to: q) } else { p.addLine(to: q) }
    }
    p.closeSubpath()
    return p
}

func arrowhead(scale s: CGFloat, dx: CGFloat, dy: CGFloat) -> CGPath {
    let pts: [(CGFloat, CGFloat)] = [(24, 12), (33, 24), (28, 24), (28, 36), (20, 36), (20, 24), (15, 24)]
    let p = CGMutablePath()
    for (i, pt) in pts.enumerated() {
        let q = CGPoint(x: dx + pt.0 * s, y: dy + pt.1 * s)
        if i == 0 { p.move(to: q) } else { p.addLine(to: q) }
    }
    p.closeSubpath()
    return p
}

func render(size: Int, draw: (CGContext, CGFloat) -> Void) -> Data {
    let cs = CGColorSpace(name: CGColorSpace.sRGB)!
    let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                        space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    // Flip so y grows downward, like the SVG grid.
    ctx.translateBy(x: 0, y: CGFloat(size))
    ctx.scaleBy(x: 1, y: -1)
    draw(ctx, CGFloat(size))
    let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
    return rep.representation(using: .png, properties: [:])!
}

func appIcon(_ size: Int) -> Data {
    render(size: size) { ctx, n in
        ctx.setFillColor(bg)
        ctx.fill(CGRect(x: 0, y: 0, width: n, height: n))
        let s = n * 0.62 / 48
        let d = (n - 48 * s) / 2
        ctx.addPath(hexagon(scale: s, dx: d, dy: d))
        ctx.setStrokeColor(accent)
        ctx.setLineWidth(2.4 * s)
        ctx.setLineJoin(.round)
        ctx.strokePath()
        ctx.addPath(arrowhead(scale: s, dx: d, dy: d))
        ctx.setFillColor(accent)
        ctx.fillPath()
    }
}

func menuBarIcon(_ size: Int) -> Data {
    render(size: size) { ctx, n in
        let s = n / 48
        ctx.addPath(hexagon(scale: s, dx: 0, dy: 0))
        ctx.setStrokeColor(CGColor(gray: 0, alpha: 1))
        ctx.setLineWidth(3.5 * s)
        ctx.setLineJoin(.round)
        ctx.strokePath()
        ctx.addPath(arrowhead(scale: s, dx: 0, dy: 0))
        ctx.setFillColor(CGColor(gray: 0, alpha: 1))
        ctx.fillPath()
    }
}

let assets = URL(fileURLWithPath: "Shared/Resources/Assets.xcassets")
let appIconDir = assets.appendingPathComponent("AppIcon.appiconset")
let menuDir = assets.appendingPathComponent("MenuBarIcon.imageset")
try FileManager.default.createDirectory(at: appIconDir, withIntermediateDirectories: true)
try FileManager.default.createDirectory(at: menuDir, withIntermediateDirectories: true)

try appIcon(1024).write(to: appIconDir.appendingPathComponent("AppIcon-1024.png"))
for px in [16, 32, 64, 128, 256, 512] {
    try appIcon(px).write(to: appIconDir.appendingPathComponent("AppIcon-mac-\(px).png"))
}
try menuBarIcon(18).write(to: menuDir.appendingPathComponent("MenuBarIcon.png"))
try menuBarIcon(36).write(to: menuDir.appendingPathComponent("MenuBarIcon@2x.png"))
print("Icons written.")
