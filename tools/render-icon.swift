#!/usr/bin/env swift
import AppKit

// Render a 1024x1024 app icon: SF Symbol "clock" on a deep blue-to-teal gradient
// with a rounded-square (macOS squircle-ish) shape.

let size = CGSize(width: 1024, height: 1024)
let cornerRadius: CGFloat = 224  // macOS Big Sur+ standard app-icon corner radius
let symbolInset: CGFloat = 190
let symbolSize = size.width - symbolInset * 2

guard let outPath = CommandLine.arguments.dropFirst().first else {
    fputs("usage: render-icon.swift OUT.png\n", stderr)
    exit(1)
}

let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: Int(size.width),
    pixelsHigh: Int(size.height),
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
)!

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

let bgRect = NSRect(origin: .zero, size: size)
let bgPath = NSBezierPath(roundedRect: bgRect, xRadius: cornerRadius, yRadius: cornerRadius)
bgPath.addClip()

let top = NSColor(red: 0.12, green: 0.22, blue: 0.38, alpha: 1.0)
let bottom = NSColor(red: 0.05, green: 0.48, blue: 0.52, alpha: 1.0)
let gradient = NSGradient(starting: top, ending: bottom)!
gradient.draw(in: bgRect, angle: -90)

let config = NSImage.SymbolConfiguration(pointSize: symbolSize, weight: .regular)
    .applying(NSImage.SymbolConfiguration(paletteColors: [.white]))
guard let base = NSImage(systemSymbolName: "clock", accessibilityDescription: nil),
      let symbol = base.withSymbolConfiguration(config) else {
    fputs("could not load SF Symbol 'clock'\n", stderr)
    exit(1)
}

let sRect = NSRect(
    x: (size.width - symbolSize) / 2,
    y: (size.height - symbolSize) / 2,
    width: symbolSize,
    height: symbolSize
)
symbol.draw(in: sRect, from: .zero, operation: .sourceOver, fraction: 1.0)

NSGraphicsContext.restoreGraphicsState()

guard let data = rep.representation(using: .png, properties: [:]) else {
    fputs("PNG encode failed\n", stderr)
    exit(1)
}
try data.write(to: URL(fileURLWithPath: outPath))
print("wrote \(outPath) (\(Int(size.width))×\(Int(size.height)))")
