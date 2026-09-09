#!/usr/bin/env swift
// Renders the disk image background: a light tile with an arrow between the app icon
// (centre 180, 150) and the Applications link (centre 480, 150) of a 660x420 window.
// Usage: swift scripts/render-dmg-background.swift <output.png>   (writes 2x pixels, 144 dpi)
import AppKit

let arguments = CommandLine.arguments
guard arguments.count == 2 else {
    FileHandle.standardError.write(Data("Usage: render-dmg-background.swift <output.png>\n".utf8))
    exit(1)
}
let scale = 2.0
let size = NSSize(width: 660 * scale, height: 420 * scale)
guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size.width), pixelsHigh: Int(size.height), bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
      let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
    FileHandle.standardError.write(Data("Could not create bitmap\n".utf8))
    exit(1)
}
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = context
NSColor(calibratedRed: 0.93, green: 0.97, blue: 0.95, alpha: 1).setFill()
NSRect(origin: .zero, size: size).fill()

// Arrow, Finder coordinates are top-left based: y 150 from the top means 420 - 150 from the bottom.
let centre = NSPoint(x: 330 * scale, y: (420 - 150) * scale)
let arrow = NSBezierPath()
arrow.lineWidth = 7 * scale
arrow.lineCapStyle = .round
arrow.lineJoinStyle = .round
arrow.move(to: NSPoint(x: centre.x - 30 * scale, y: centre.y))
arrow.line(to: NSPoint(x: centre.x + 30 * scale, y: centre.y))
arrow.move(to: NSPoint(x: centre.x + 10 * scale, y: centre.y + 20 * scale))
arrow.line(to: NSPoint(x: centre.x + 30 * scale, y: centre.y))
arrow.line(to: NSPoint(x: centre.x + 10 * scale, y: centre.y - 20 * scale))
NSColor(calibratedRed: 0.05, green: 0.36, blue: 0.27, alpha: 1).setStroke()
arrow.stroke()

NSGraphicsContext.restoreGraphicsState()
bitmap.size = NSSize(width: 660, height: 420)
guard let png = bitmap.representation(using: .png, properties: [:]) else {
    exit(1)
}
do {
    try png.write(to: URL(fileURLWithPath: arguments[1]))
} catch {
    FileHandle.standardError.write(Data("Could not write \(arguments[1]): \(error)\n".utf8))
    exit(1)
}
print("Wrote \(arguments[1])")
