#!/usr/bin/env swift
import AppKit
import Foundation

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let resources = root.appendingPathComponent("Resources", isDirectory: true)
let iconset = resources.appendingPathComponent("AppIcon.iconset", isDirectory: true)
let icns = resources.appendingPathComponent("AppIcon.icns")
let fileManager = FileManager.default

try? fileManager.removeItem(at: iconset)
try fileManager.createDirectory(at: iconset, withIntermediateDirectories: true)

let specs: [(String, CGFloat)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

func writePNG(named name: String, pixels: CGFloat) throws {
    let size = NSSize(width: pixels, height: pixels)
    let image = NSImage(size: size)
    image.lockFocus()

    let bounds = NSRect(origin: .zero, size: size)
    NSColor.black.setFill()
    bounds.fill()

    let inset = pixels * 0.08
    let rounded = NSBezierPath(roundedRect: bounds.insetBy(dx: inset, dy: inset), xRadius: pixels * 0.20, yRadius: pixels * 0.20)
    NSColor(srgbRed: 0.04, green: 0.08, blue: 0.10, alpha: 1).setFill()
    rounded.fill()

    let stroke = NSBezierPath(roundedRect: bounds.insetBy(dx: inset + pixels * 0.025, dy: inset + pixels * 0.025), xRadius: pixels * 0.17, yRadius: pixels * 0.17)
    NSColor(srgbRed: 0.54, green: 0.92, blue: 1.0, alpha: 0.55).setStroke()
    stroke.lineWidth = max(1, pixels * 0.018)
    stroke.stroke()

    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center
    let font = NSFont.monospacedSystemFont(ofSize: pixels * 0.29, weight: .heavy)
    let attributes: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: NSColor.white,
        .paragraphStyle: paragraph,
        .kern: -pixels * 0.038
    ]
    let text = "<//>" as NSString
    let textSize = text.size(withAttributes: attributes)
    let textRect = NSRect(
        x: 0,
        y: (pixels - textSize.height) / 2 - pixels * 0.01,
        width: pixels,
        height: textSize.height
    )
    text.draw(in: textRect, withAttributes: attributes)

    image.unlockFocus()

    guard let tiff = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff),
          let png = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "puz.icon", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not encode PNG"])
    }
    try png.write(to: iconset.appendingPathComponent(name))
}

for spec in specs {
    try writePNG(named: spec.0, pixels: spec.1)
}

try? fileManager.removeItem(at: icns)
let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconset.path, "-o", icns.path]
try process.run()
process.waitUntilExit()
if process.terminationStatus != 0 {
    throw NSError(domain: "puz.icon", code: Int(process.terminationStatus), userInfo: [NSLocalizedDescriptionKey: "iconutil failed"])
}

print("Wrote \(icns.path)")
