import AppKit
import CoreGraphics

func createMenubarImage(size: CGFloat) -> NSImage {
    let img = NSImage(size: NSSize(width: size, height: size))
    img.lockFocus()
    guard let ctx = NSGraphicsContext.current?.cgContext else {
        img.unlockFocus()
        return img
    }
    
    ctx.clear(CGRect(x: 0, y: 0, width: size, height: size))
    ctx.setAllowsAntialiasing(true)
    ctx.setShouldAntialias(true)
    ctx.setFillColor(NSColor.black.cgColor)
    
    let stemX = size * 0.16
    let stemW = size * 0.22
    let topY = size * 0.84
    let botY = size * 0.16
    
    let stemRect = CGRect(x: stemX, y: botY, width: stemW, height: topY - botY)
    let stemPath = CGPath(roundedRect: stemRect, cornerWidth: size * 0.03, cornerHeight: size * 0.03, transform: nil)
    ctx.addPath(stemPath)
    ctx.fillPath()
    
    let arm = CGMutablePath()
    arm.move(to: CGPoint(x: stemX + stemW - 0.5, y: size * 0.46))
    arm.addLine(to: CGPoint(x: size * 0.62, y: topY))
    arm.addLine(to: CGPoint(x: size * 0.84, y: topY))
    arm.addLine(to: CGPoint(x: stemX + stemW - 0.5, y: size * 0.35))
    arm.closeSubpath()
    ctx.addPath(arm)
    ctx.fillPath()
    
    let bolt = CGMutablePath()
    bolt.move(to: CGPoint(x: size * 0.50, y: size * 0.44))
    bolt.addLine(to: CGPoint(x: size * 0.68, y: size * 0.44))
    bolt.addLine(to: CGPoint(x: size * 0.78, y: size * 0.31))
    bolt.addLine(to: CGPoint(x: size * 0.68, y: size * 0.31))
    bolt.addLine(to: CGPoint(x: size * 0.84, y: botY))
    bolt.addLine(to: CGPoint(x: size * 0.54, y: size * 0.24))
    bolt.addLine(to: CGPoint(x: size * 0.63, y: size * 0.24))
    bolt.closeSubpath()
    ctx.addPath(bolt)
    ctx.fillPath()
    
    img.unlockFocus()
    img.isTemplate = true
    return img
}

func createAppIconImage(size: CGFloat) -> NSImage {
    let img = NSImage(size: NSSize(width: size, height: size))
    img.lockFocus()
    guard let ctx = NSGraphicsContext.current?.cgContext else {
        img.unlockFocus()
        return img
    }
    
    ctx.clear(CGRect(x: 0, y: 0, width: size, height: size))
    ctx.setAllowsAntialiasing(true)
    ctx.setShouldAntialias(true)
    
    let rect = CGRect(x: 0, y: 0, width: size, height: size)
    let cornerRadius = size * 0.224
    let path = CGPath(roundedRect: rect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
    
    ctx.saveGState()
    ctx.addPath(path)
    ctx.clip()
    
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bgColors = [
        NSColor(red: 28/255, green: 28/255, blue: 34/255, alpha: 1.0).cgColor,
        NSColor(red: 14/255, green: 14/255, blue: 17/255, alpha: 1.0).cgColor
    ] as CFArray
    let bgGrad = CGGradient(colorsSpace: colorSpace, colors: bgColors, locations: [0.0, 1.0])!
    ctx.drawLinearGradient(bgGrad, start: CGPoint(x: size/2, y: size), end: CGPoint(x: size/2, y: 0), options: [])
    
    let glowCenter = CGPoint(x: size * 0.68, y: size * 0.30)
    let glowColors = [
        NSColor(red: 56/255, green: 189/255, blue: 248/255, alpha: 0.40).cgColor,
        NSColor(red: 56/255, green: 189/255, blue: 248/255, alpha: 0.0).cgColor
    ] as CFArray
    let glowGrad = CGGradient(colorsSpace: colorSpace, colors: glowColors, locations: [0.0, 1.0])!
    ctx.drawRadialGradient(glowGrad, startCenter: glowCenter, startRadius: 0, endCenter: glowCenter, endRadius: size * 0.42, options: [])
    
    let insetRect = rect.insetBy(dx: max(1, size * 0.015), dy: max(1, size * 0.015))
    let insetPath = CGPath(roundedRect: insetRect, cornerWidth: cornerRadius * 0.98, cornerHeight: cornerRadius * 0.98, transform: nil)
    ctx.addPath(insetPath)
    ctx.setStrokeColor(NSColor(white: 1.0, alpha: 0.10).cgColor)
    ctx.setLineWidth(max(1.0, size * 0.015))
    ctx.strokePath()
    
    let stemX = size * 0.22
    let stemW = size * 0.22
    let topY = size * 0.82
    let botY = size * 0.18
    
    ctx.setFillColor(NSColor(red: 250/255, green: 250/255, blue: 252/255, alpha: 1.0).cgColor)
    
    let stemRect = CGRect(x: stemX, y: botY, width: stemW, height: topY - botY)
    let stemP = CGPath(roundedRect: stemRect, cornerWidth: size * 0.02, cornerHeight: size * 0.02, transform: nil)
    ctx.addPath(stemP)
    ctx.fillPath()
    
    let arm = CGMutablePath()
    arm.move(to: CGPoint(x: stemX + stemW - 0.5, y: size * 0.48))
    arm.addLine(to: CGPoint(x: size * 0.64, y: topY))
    arm.addLine(to: CGPoint(x: size * 0.84, y: topY))
    arm.addLine(to: CGPoint(x: stemX + stemW - 0.5, y: size * 0.36))
    arm.closeSubpath()
    ctx.addPath(arm)
    ctx.fillPath()
    
    let skyColors = [
        NSColor(red: 125/255, green: 211/255, blue: 252/255, alpha: 1.0).cgColor,
        NSColor(red: 56/255, green: 189/255, blue: 248/255, alpha: 1.0).cgColor
    ] as CFArray
    let skyGrad = CGGradient(colorsSpace: colorSpace, colors: skyColors, locations: [0.0, 1.0])!
    
    let bolt = CGMutablePath()
    bolt.move(to: CGPoint(x: size * 0.52, y: size * 0.44))
    bolt.addLine(to: CGPoint(x: size * 0.67, y: size * 0.44))
    bolt.addLine(to: CGPoint(x: size * 0.77, y: size * 0.32))
    bolt.addLine(to: CGPoint(x: size * 0.67, y: size * 0.32))
    bolt.addLine(to: CGPoint(x: size * 0.82, y: botY))
    bolt.addLine(to: CGPoint(x: size * 0.56, y: size * 0.25))
    bolt.addLine(to: CGPoint(x: size * 0.64, y: size * 0.25))
    bolt.closeSubpath()
    
    ctx.saveGState()
    ctx.addPath(bolt)
    ctx.clip()
    ctx.drawLinearGradient(skyGrad, start: CGPoint(x: size * 0.52, y: size * 0.44), end: CGPoint(x: size * 0.82, y: botY), options: [])
    ctx.restoreGState()
    
    ctx.restoreGState()
    
    img.unlockFocus()
    return img
}

func savePNG(image: NSImage, path: String) {
    guard let tiff = image.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let png = rep.representation(using: .png, properties: [:]) else {
        print("Failed to convert image to PNG for \(path)")
        return
    }
    do {
        try png.write(to: URL(fileURLWithPath: path))
        print("Saved: \(path)")
    } catch {
        print("Error saving \(path): \(error)")
    }
}

let iconsDir = FileManager.default.fileExists(atPath: "Support/Icons") ? "Support/Icons" : (FileManager.default.fileExists(atPath: "app/Support/Icons") ? "app/Support/Icons" : ".")

let mb1 = createMenubarImage(size: 18)
savePNG(image: mb1, path: "\(iconsDir)/status-icon.png")
savePNG(image: mb1, path: "\(iconsDir)/menubar.png")

let mb2 = createMenubarImage(size: 36)
savePNG(image: mb2, path: "\(iconsDir)/status-icon@2x.png")
savePNG(image: mb2, path: "\(iconsDir)/menubar@2x.png")

let sizes: [(String, CGFloat)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_64x64.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024),
    ("icon_1024x1024.png", 1024)
]

let iconsetSizes: [(String, CGFloat)] = [
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

for (name, size) in sizes {
    let img = createAppIconImage(size: size)
    savePNG(image: img, path: "\(iconsDir)/\(name)")
}

for (name, size) in iconsetSizes {
    let img = createAppIconImage(size: size)
    savePNG(image: img, path: "\(iconsDir)/AppIcon.iconset/\(name)")
}

let iconsetPath = "\(iconsDir)/AppIcon.iconset"
let icnsPath = "\(iconsDir)/AppIcon.icns"
let task = Process()
task.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
task.arguments = ["-c", "icns", iconsetPath, "-o", icnsPath]
try? task.run()
task.waitUntilExit()

print("Icon generation completed!")
