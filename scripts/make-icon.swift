import AppKit
import CoreGraphics
import Foundation

// Draws the Voxel app icon: a white line-art isometric cube on a black rounded square, 1024x1024 PNG.
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

// macOS-style tile: 100px inset, corner radius about 22.5%, a faint rim so it stays visible on dark wallpapers.
let tile = CGRect(x: 100, y: 100, width: 824, height: 824)
let tilePath = CGPath(roundedRect: tile, cornerWidth: 185, cornerHeight: 185, transform: nil)
ctx.addPath(tilePath)
ctx.setFillColor(CGColor(red: 0.04, green: 0.04, blue: 0.045, alpha: 1))
ctx.fillPath()
ctx.addPath(tilePath)
ctx.setStrokeColor(CGColor(red: 0.24, green: 0.24, blue: 0.27, alpha: 1))
ctx.setLineWidth(3)
ctx.strokePath()

// Cube outline: hexagon plus the three edges meeting in the centre.
let c = CGPoint(x: 512, y: 512)
let s: CGFloat = 290
let w = s * cos(.pi / 6)
func pt(_ dx: CGFloat, _ dy: CGFloat) -> CGPoint { CGPoint(x: c.x + dx, y: c.y + dy) }
let hexagon = [pt(0, -s), pt(w, -s / 2), pt(w, s / 2), pt(0, s), pt(-w, s / 2), pt(-w, -s / 2)]
ctx.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
ctx.setLineWidth(24)
ctx.setLineCap(.round)
ctx.setLineJoin(.round)
ctx.addLines(between: hexagon)
ctx.closePath()
for corner in [hexagon[1], hexagon[3], hexagon[5]] {
    ctx.move(to: c)
    ctx.addLine(to: corner)
}
ctx.strokePath()

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
