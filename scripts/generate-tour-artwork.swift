// Rebuild Husk's own tour illustrations. Uses existing brand art and system symbols.
// Run from the repo root: swift scripts/generate-tour-artwork.swift
import AppKit

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let assets = root.appendingPathComponent("Husk/Husk/Assets.xcassets")
let size = NSSize(width: 1160, height: 725)
var isDark = false
var amber: NSColor { isDark ? NSColor(red: 0.91, green: 0.643, blue: 0.361, alpha: 1) : NSColor(red: 0.50, green: 0.30, blue: 0.10, alpha: 1) }
var teal: NSColor { isDark ? NSColor(red: 0.467, green: 0.839, blue: 0.824, alpha: 1) : NSColor(red: 0.12, green: 0.44, blue: 0.43, alpha: 1) }
var ink: NSColor { isDark ? .white : NSColor(white: 0.12, alpha: 1) }
var mutedInk: NSColor { isDark ? .lightGray : NSColor(white: 0.38, alpha: 1) }

func panel(_ rect: NSRect, radius: CGFloat = 24) {
    let shape = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
    NSColor(white: isDark ? 0.14 : 1, alpha: 1).setFill(); shape.fill()
    NSColor(white: isDark ? 1 : 0, alpha: 0.13).setStroke(); shape.lineWidth = 2; shape.stroke()
}
func text(_ value: String, x: CGFloat, y: CGFloat, font: NSFont, color: NSColor? = nil) {
    (value as NSString).draw(at: NSPoint(x: x, y: y), withAttributes: [.font: font, .foregroundColor: color ?? ink])
}
func symbol(_ name: String, rect: NSRect, tint: NSColor) {
    guard let image = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
        .withSymbolConfiguration(.init(pointSize: rect.height, weight: .regular)) else { fatalError("Missing symbol " + name) }
    let colored = NSImage(size: image.size, flipped: false) { _ in
        image.draw(at: .zero, from: .zero, operation: .sourceOver, fraction: 1)
        tint.setFill(); NSRect(origin: .zero, size: image.size).fill(using: .sourceAtop)
        return true
    }
    colored.draw(in: rect)
}
func render(_ name: String, draw: () -> Void) throws {
    let folder = assets.appendingPathComponent(name + ".imageset")
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    for appearance in ["light", "dark"] {
        isDark = appearance == "dark"
        guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size.width), pixelsHigh: Int(size.height), bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
              let context = NSGraphicsContext(bitmapImageRep: bitmap) else { fatalError("Cannot create illustration") }
        NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = context
        context.cgContext.clear(CGRect(origin: .zero, size: size))
        draw()
        NSGraphicsContext.restoreGraphicsState()
        try bitmap.representation(using: .png, properties: [:])!.write(to: folder.appendingPathComponent("artwork-" + appearance + ".png"))
    }
    let catalog = """
    {"images":[{"filename":"artwork-light.png","idiom":"universal"},{"filename":"artwork-dark.png","idiom":"universal","appearances":[{"appearance":"luminosity","value":"dark"}]}],"info":{"author":"xcode","version":1}}
    """
    try catalog.write(to: folder.appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)
    let oldArtwork = folder.appendingPathComponent("artwork.png")
    if FileManager.default.fileExists(atPath: oldArtwork.path) { try FileManager.default.removeItem(at: oldArtwork) }
}

try render("TourWelcome") {
    guard let logo = NSImage(contentsOf: assets.appendingPathComponent("HuskLogo.imageset/husk-logo.png")) else { fatalError("Brand image missing") }
    logo.draw(in: NSRect(x: 375, y: 260, width: 410, height: 410))
    for (index, name) in ["internaldrive", "sparkle.magnifyingglass", "trash"].enumerated() {
        let x = CGFloat(375 + index * 146)
        panel(NSRect(x: x, y: 132, width: 118, height: 86), radius: 22)
        symbol(name, rect: NSRect(x: x + 39, y: 156, width: 40, height: 40), tint: amber)
    }
}
try render("TourReview") {
    panel(NSRect(x: 184, y: 212, width: 792, height: 360))
    text("Your cleanup. Your call.", x: 220, y: 505, font: .systemFont(ofSize: 28, weight: .semibold))
    let names = ["Build cache", "Package downloads", "App cache"]
    let sizes = ["2.3 GB", "483 MB", "231 MB"]
    for index in names.indices {
        let y = CGFloat(412 - index * 82)
        panel(NSRect(x: 220, y: y, width: 720, height: 64), radius: 12)
        symbol("checkmark.circle", rect: NSRect(x: 242, y: y + 17, width: 30, height: 30), tint: amber)
        text(names[index], x: 294, y: y + 20, font: .systemFont(ofSize: 23, weight: .medium))
        text(sizes[index], x: 806, y: y + 20, font: .monospacedDigitSystemFont(ofSize: 23, weight: .medium), color: amber)
    }
}
try render("TourAI") {
    let cards: [(String, String, CGFloat, CGFloat, NSColor)] = [
        ("Caches", "Review for cleanup", 214, 386, amber),
        ("Sessions", "Keep your conversations", 448, 316, teal),
        ("Worktrees", "Keep your working copies", 682, 246, teal)
    ]
    for (index, card) in cards.enumerated() {
        panel(NSRect(x: card.2, y: card.3, width: 260, height: 208))
        symbol(index == 0 ? "cpu" : index == 1 ? "bubble.left.and.bubble.right" : "arrow.triangle.branch",
               rect: NSRect(x: card.2 + 24, y: card.3 + 130, width: 44, height: 44), tint: card.4)
        text(card.0, x: card.2 + 24, y: card.3 + 82, font: .systemFont(ofSize: 26, weight: .semibold))
        text(card.1, x: card.2 + 24, y: card.3 + 48, font: .systemFont(ofSize: 16), color: mutedInk)
        symbol(index == 0 ? "eye" : "lock", rect: NSRect(x: card.2 + 208, y: card.3 + 148, width: 22, height: 22), tint: card.4)
    }
}
print("Generated 3 transparent tour illustrations in light and dark variants.")
