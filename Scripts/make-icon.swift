// Generates Renamr's app icon: a brand-gradient squircle with a white wand mark.
// Run:  swift Scripts/make-icon.swift   (writes build/Renamr.iconset/*.png)
// Then: iconutil -c icns build/Renamr.iconset -o Resources/AppIcon.icns
import AppKit
import Foundation

func makePNG(px: Int) -> Data {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    let ctx = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = ctx
    let cg = ctx.cgContext
    let s = CGFloat(px)
    let rect = CGRect(x: 0, y: 0, width: s, height: s)

    // Squircle clip (Big Sur-ish corner radius).
    let clip = CGPath(roundedRect: rect, cornerWidth: s * 0.2237, cornerHeight: s * 0.2237, transform: nil)
    cg.addPath(clip); cg.clip()

    // Brand gradient: indigo -> violet, top-left to bottom-right.
    let cs = CGColorSpaceCreateDeviceRGB()
    let c0 = NSColor(srgbRed: 0.40, green: 0.34, blue: 0.97, alpha: 1).cgColor
    let c1 = NSColor(srgbRed: 0.73, green: 0.30, blue: 0.96, alpha: 1).cgColor
    let grad = CGGradient(colorsSpace: cs, colors: [c0, c1] as CFArray, locations: [0, 1])!
    cg.drawLinearGradient(grad, start: CGPoint(x: 0, y: s), end: CGPoint(x: s, y: 0), options: [])

    // Soft top highlight for a little life.
    let hi = CGGradient(colorsSpace: cs,
                        colors: [NSColor(white: 1, alpha: 0.18).cgColor, NSColor(white: 1, alpha: 0).cgColor] as CFArray,
                        locations: [0, 1])!
    cg.drawRadialGradient(hi, startCenter: CGPoint(x: s * 0.3, y: s * 0.8), startRadius: 0,
                          endCenter: CGPoint(x: s * 0.3, y: s * 0.8), endRadius: s * 0.7, options: [])

    // White wand-and-stars mark, centered.
    if let sym = NSImage(systemSymbolName: "wand.and.stars", accessibilityDescription: nil) {
        let conf = NSImage.SymbolConfiguration(pointSize: s * 0.42, weight: .semibold)
            .applying(NSImage.SymbolConfiguration(paletteColors: [.white]))
        if let glyph = sym.withSymbolConfiguration(conf) {
            let target = s * 0.58
            let scale = target / max(glyph.size.width, glyph.size.height)
            let dw = glyph.size.width * scale, dh = glyph.size.height * scale
            glyph.draw(in: NSRect(x: (s - dw) / 2, y: (s - dh) / 2, width: dw, height: dh),
                       from: .zero, operation: .sourceOver, fraction: 1.0)
        }
    }

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let sizes: [(String, Int)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32),
    ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256),
    ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024),
]
let dir = "build/Renamr.iconset"
try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
for (name, px) in sizes {
    try! makePNG(px: px).write(to: URL(fileURLWithPath: "\(dir)/\(name).png"))
}
print("wrote \(sizes.count) PNGs to \(dir)")
