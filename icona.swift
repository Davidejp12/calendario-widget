// Disegna l'icona 1024x1024 del widget calendario (palette prugna/nebbia).
import Cocoa

let S: CGFloat = 1024
let img = NSImage(size: NSSize(width: S, height: S))
img.lockFocus()
let rgb = { (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat) in NSColor(srgbRed: r/255, green: g/255, blue: b/255, alpha: a) }

// fondo: squircle macOS (824px con margine 100)
let body = NSRect(x: 100, y: 100, width: 824, height: 824)
let shape = NSBezierPath(roundedRect: body, xRadius: 185, yRadius: 185)
NSGradient(starting: rgb(74, 42, 66, 1), ending: rgb(38, 22, 36, 1))!.draw(in: shape, angle: -90)

// foglio del calendario
let sheet = NSRect(x: 220, y: 210, width: 584, height: 560)
let sheetPath = NSBezierPath(roundedRect: sheet, xRadius: 70, yRadius: 70)
rgb(243, 236, 242, 1).setFill(); sheetPath.fill()

// fascia superiore
NSGraphicsContext.saveGraphicsState()
sheetPath.addClip()
rgb(217, 169, 198, 1).setFill()
NSRect(x: sheet.minX, y: sheet.maxY - 150, width: sheet.width, height: 150).fill()
NSGraphicsContext.restoreGraphicsState()

// anelli
for x in [360.0, 664.0] {
    rgb(38, 22, 36, 1).setFill()
    NSBezierPath(roundedRect: NSRect(x: x - 22, y: sheet.maxY - 60, width: 44, height: 120), xRadius: 22, yRadius: 22).fill()
}

// griglia giorni 5x4, uno evidenziato
let cols = 5, rows = 4
let gx = sheet.minX + 70, gy = sheet.minY + 60
let cw = (sheet.width - 140) / CGFloat(cols - 1), ch: CGFloat = 95
for r in 0..<rows {
    for c in 0..<cols {
        let cx = gx + CGFloat(c) * cw, cy = gy + CGFloat(r) * ch
        if r == 2 && c == 3 {
            rgb(185, 138, 168, 1).setFill()
            NSBezierPath(ovalIn: NSRect(x: cx - 40, y: cy - 40, width: 80, height: 80)).fill()
        } else {
            rgb(143, 122, 140, 0.55).setFill()
            NSBezierPath(ovalIn: NSRect(x: cx - 17, y: cy - 17, width: 34, height: 34)).fill()
        }
    }
}
img.unlockFocus()

let rep = NSBitmapImageRep(data: img.tiffRepresentation!)!
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
