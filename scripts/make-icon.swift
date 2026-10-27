import AppKit
import CoreGraphics
import Foundation

 // Draws the Ember logo (a violet‑orange diamond gem on a dark rounded tile), 1024x1024 PNG.
guard CommandLine.arguments.count > 1 else {
    fputs("Usage: swift scripts/make-icon.swift <output.png>\n", stderr)
    exit(1)
}
let outputPath = CommandLine.arguments[1]

let size = 1024
guard let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8, samplesPerPixel: 4,
    hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
), let gfx = NSGraphicsContext(bitmapImageRep: rep) else {
    fputs("Cannot create bitmap\n", stderr)
    exit(1)
}
NSGraphicsContext.current = gfx
let ctx = gfx.cgContext
// Origin top-left, y grows downward.
ctx.translateBy(x: 0, y: CGFloat(size))
ctx.scaleBy(x: 1, y: -1)

func rgb(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    let r = CGFloat((hex >> 16) & 0xFF) / 255.0
    let g = CGFloat((hex >> 8) & 0xFF) / 255.0
    let b = CGFloat(hex & 0xFF) / 255.0
    return CGColor(red: r, green: g, blue: b, alpha: alpha)
}

 // Tile background
let tileRect = CGRect(x: 100, y: 100, width: 824, height: 824)
let tilePath = CGPath(roundedRect: tileRect, cornerWidth: 185, cornerHeight: 185, transform: nil)
ctx.saveGState()
ctx.addPath(tilePath)
ctx.clip()

// dark near‑black gradient
let bgColors: [CGColor] = [rgb(0x1B1522), rgb(0x0E0B13)]
let bgLocations: [CGFloat] = [0, 1]
let bgGradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                           colors: bgColors as CFArray,
                           locations: bgLocations)!
ctx.drawLinearGradient(bgGradient,
                       start: CGPoint(x: 212, y: 108),
                       end:   CGPoint(x: 812, y: 916),
                       options: [])
ctx.restoreGState()

// thin inner white stroke
ctx.saveGState()
ctx.addPath(tilePath)
ctx.setStrokeColor(rgb(0xFFFFFF, 0.07))
ctx.setLineWidth(3)
ctx.strokePath()
ctx.restoreGState()

// Warm glow behind the gem (clipped to tile)
ctx.saveGState()
ctx.addPath(tilePath)
ctx.clip()
let glowCenter = CGPoint(x: 512, y: 512)
let glowColors: [CGColor] = [
    rgb(0xF2A164, 0.42),
    rgb(0xF2A164, 0.0)
]
let glowGradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                              colors: glowColors as CFArray,
                              locations: [0, 1])!
ctx.drawRadialGradient(glowGradient,
                       startCenter: glowCenter, startRadius: 0,
                       endCenter: glowCenter, endRadius: 340,
                       options: [])
ctx.restoreGState()

// Diamond geometry
let halfDiag: CGFloat = 290
let cx: CGFloat = 512, cy: CGFloat = 512
let T = CGPoint(x: cx, y: cy - halfDiag)
let R = CGPoint(x: cx + halfDiag, y: cy)
let B = CGPoint(x: cx, y: cy + halfDiag)
let L = CGPoint(x: cx - halfDiag, y: cy)
let C = CGPoint(x: cx, y: cy)

// Rhombus path
let gemPath = CGMutablePath()
gemPath.move(to: T)
gemPath.addLine(to: R)
gemPath.addLine(to: B)
gemPath.addLine(to: L)
gemPath.closeSubpath()

// Soft orange glow shadow
ctx.saveGState()
ctx.addPath(gemPath)
ctx.setShadow(offset: CGSize(width: 0, height: -10),
              blur: 50,
              color: rgb(0xF2A164, 0.55))
ctx.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 0.01))
ctx.fillPath()
ctx.restoreGState()

// Facet fills
func drawFacet(_ p1: CGPoint, _ p2: CGPoint, _ p3: CGPoint,
               startColor: CGColor, endColor: CGColor) {
    let facetPath = CGMutablePath()
    facetPath.move(to: p1)
    facetPath.addLine(to: p2)
    facetPath.addLine(to: p3)
    facetPath.closeSubpath()
    ctx.saveGState()
    ctx.addPath(facetPath)
    ctx.clip()
    let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                         colors: [startColor, endColor] as CFArray,
                         locations: [0, 1])!
    ctx.drawLinearGradient(grad,
                           start: p1, end: p2,
                           options: [])
    ctx.restoreGState()
}

// top‑left facet (T, L, C)
drawFacet(T, L, C,
          startColor: rgb(0xE9B6FF),
          endColor:   rgb(0xB468DC))

// top‑right facet (T, R, C)
drawFacet(T, R, C,
          startColor: rgb(0xF6D2FF),
          endColor:   rgb(0xCB86E8))

// bottom‑left facet (L, B, C)
drawFacet(L, B, C,
          startColor: rgb(0xE98A55),
          endColor:   rgb(0xF7B27A))

// bottom‑right facet (R, B, C)
drawFacet(R, B, C,
          startColor: rgb(0xF9C08A),
          endColor:   rgb(0xE5783F))

// Facet edge strokes
ctx.saveGState()
ctx.setStrokeColor(rgb(0xFFFFFF, 0.18))
ctx.setLineWidth(3)
let edgeLines = [(T, C), (L, C), (R, C), (B, C)]
for (pStart, pEnd) in edgeLines {
    ctx.move(to: pStart)
    ctx.addLine(to: pEnd)
}
ctx.strokePath()
ctx.restoreGState()

// Rhombus outline
ctx.saveGState()
ctx.addPath(gemPath)
ctx.setStrokeColor(rgb(0xFFFFFF, 0.35))
ctx.setLineWidth(4)
ctx.setLineJoin(.miter)
ctx.strokePath()
ctx.restoreGState()

// Inner highlight rhombus
let innerHalf: CGFloat = 160
let innerPath = CGMutablePath()
innerPath.move(to: CGPoint(x: cx, y: cy - innerHalf))
innerPath.addLine(to: CGPoint(x: cx + innerHalf, y: cy))
innerPath.addLine(to: CGPoint(x: cx, y: cy + innerHalf))
innerPath.addLine(to: CGPoint(x: cx - innerHalf, y: cy))
innerPath.closeSubpath()
ctx.saveGState()
ctx.addPath(innerPath)
ctx.setStrokeColor(rgb(0xFFFFFF, 0.14))
ctx.setLineWidth(3)
ctx.strokePath()
ctx.restoreGState()

gfx.flushGraphics()
guard let png = rep.representation(using: .png, properties: [:]) else {
    fputs("Cannot encode PNG\n", stderr)
    exit(1)
}
do {
    try png.write(to: URL(fileURLWithPath: outputPath))
} catch {
    fputs("Cannot write \(outputPath): \(error)\n", stderr)
    exit(1)
}
