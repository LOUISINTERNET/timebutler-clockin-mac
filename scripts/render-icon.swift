#!/usr/bin/env swift
// Renders the placeholder app icon (SF Symbol clock.badge.checkmark on a gradient tile)
// as a 1024 px PNG. Usage: swift scripts/render-icon.swift <output.png>
import AppKit

let arguments = CommandLine.arguments
guard arguments.count == 2 else {
    FileHandle.standardError.write(Data("Usage: render-icon.swift <output.png>\n".utf8))
    exit(1)
}
let outputURL = URL(fileURLWithPath: arguments[1])
let size = 1024.0
let canvas = NSRect(x: 0, y: 0, width: size, height: size)

guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size), bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else {
    FileHandle.standardError.write(Data("Could not create bitmap\n".utf8))
    exit(1)
}
guard let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
    FileHandle.standardError.write(Data("Could not create graphics context\n".utf8))
    exit(1)
}
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = context

// macOS icon grid: the tile fills 824 of 1024 points.
let tile = canvas.insetBy(dx: size * 0.0977, dy: size * 0.0977)
let tilePath = NSBezierPath(roundedRect: tile, xRadius: tile.width * 0.2237, yRadius: tile.height * 0.2237)
guard let gradient = NSGradient(starting: NSColor(calibratedRed: 0.16, green: 0.62, blue: 0.42, alpha: 1), ending: NSColor(calibratedRed: 0.05, green: 0.36, blue: 0.27, alpha: 1)) else {
    FileHandle.standardError.write(Data("Could not create gradient\n".utf8))
    exit(1)
}
gradient.draw(in: tilePath, angle: -90)

let configuration = NSImage.SymbolConfiguration(pointSize: size * 0.46, weight: .medium)
guard let symbol = NSImage(systemSymbolName: "clock.badge.checkmark", accessibilityDescription: nil)?.withSymbolConfiguration(configuration) else {
    FileHandle.standardError.write(Data("SF Symbol clock.badge.checkmark not available\n".utf8))
    exit(1)
}
let symbolSize = symbol.size
let symbolRect = NSRect(x: (size - symbolSize.width) / 2, y: (size - symbolSize.height) / 2, width: symbolSize.width, height: symbolSize.height)
NSColor.white.set()
symbol.isTemplate = true
guard let tinted = symbol.copy() as? NSImage else {
    exit(1)
}
tinted.lockFocus()
NSColor.white.set()
NSRect(origin: .zero, size: tinted.size).fill(using: .sourceAtop)
tinted.unlockFocus()
tinted.draw(in: symbolRect, from: .zero, operation: .sourceOver, fraction: 1)

NSGraphicsContext.restoreGraphicsState()
guard let png = bitmap.representation(using: .png, properties: [:]) else {
    FileHandle.standardError.write(Data("Could not encode PNG\n".utf8))
    exit(1)
}
do {
    try png.write(to: outputURL)
} catch {
    FileHandle.standardError.write(Data("Could not write \(outputURL.path): \(error)\n".utf8))
    exit(1)
}
print("Wrote \(outputURL.path)")
