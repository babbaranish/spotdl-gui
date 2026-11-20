// Renders the app icon to a 1024x1024 PNG: swift scripts/make-icon.swift out.png
import AppKit

let size: CGFloat = 1024
let out = CommandLine.arguments[1]
let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()

// macOS icon grid: 824pt body centred in a 1024 canvas.
let body = NSRect(x: 100, y: 100, width: 824, height: 824)
let path = NSBezierPath(roundedRect: body, xRadius: 185, yRadius: 185)
NSGradient(colors: [
    NSColor(red: 0.13, green: 0.80, blue: 0.42, alpha: 1),
    NSColor(red: 0.04, green: 0.50, blue: 0.27, alpha: 1),
])!.draw(in: path, angle: -90)

func symbol(_ name: String, _ points: CGFloat, _ color: NSColor) -> NSImage {
    let cfg = NSImage.SymbolConfiguration(pointSize: points, weight: .semibold)
        .applying(NSImage.SymbolConfiguration(paletteColors: [color]))
    return NSImage(systemSymbolName: name, accessibilityDescription: nil)!.withSymbolConfiguration(cfg)!
}

let note = symbol("music.note", 430, .white)
note.draw(in: NSRect(x: 512 - note.size.width / 2 - 40, y: 512 - note.size.height / 2 + 30,
                     width: note.size.width, height: note.size.height))

// Download badge, bottom right.
let badge = NSRect(x: 590, y: 170, width: 250, height: 250)
NSColor.white.setFill()
NSBezierPath(ovalIn: badge).fill()
let arrow = symbol("arrow.down", 150, NSColor(red: 0.05, green: 0.55, blue: 0.29, alpha: 1))
arrow.draw(in: NSRect(x: badge.midX - arrow.size.width / 2, y: badge.midY - arrow.size.height / 2,
                      width: arrow.size.width, height: arrow.size.height))

image.unlockFocus()
let rep = NSBitmapImageRep(data: image.tiffRepresentation!)!
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
