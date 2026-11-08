import AppKit

enum IconMaker {
    /// A cute pastel folder with an emoji on the front.
    static func folderIcon(emoji: String, color: NSColor) -> NSImage {
        NSImage(size: NSSize(width: 512, height: 512), flipped: false) { rect in
            let s = rect.width
            let back = color.blended(withFraction: 0.18, of: .systemPink) ?? color
            let shadow = NSShadow()
            shadow.shadowColor = NSColor.black.withAlphaComponent(0.15)
            shadow.shadowOffset = NSSize(width: 0, height: -s * 0.012)
            shadow.shadowBlurRadius = s * 0.025

            NSGraphicsContext.saveGraphicsState()
            shadow.set()
            back.setFill()
            NSBezierPath(roundedRect: NSRect(x: s * 0.08, y: s * 0.60, width: s * 0.36, height: s * 0.16),
                         xRadius: s * 0.05, yRadius: s * 0.05).fill()
            NSBezierPath(roundedRect: NSRect(x: s * 0.08, y: s * 0.16, width: s * 0.84, height: s * 0.54),
                         xRadius: s * 0.07, yRadius: s * 0.07).fill()
            color.setFill()
            NSBezierPath(roundedRect: NSRect(x: s * 0.08, y: s * 0.14, width: s * 0.84, height: s * 0.48),
                         xRadius: s * 0.07, yRadius: s * 0.07).fill()
            NSGraphicsContext.restoreGraphicsState()

            // little shine along the top edge
            NSColor.white.withAlphaComponent(0.45).setFill()
            NSBezierPath(roundedRect: NSRect(x: s * 0.13, y: s * 0.54, width: s * 0.74, height: s * 0.035),
                         xRadius: s * 0.018, yRadius: s * 0.018).fill()

            let text = NSAttributedString(string: emoji, attributes: [.font: NSFont.systemFont(ofSize: s * 0.26)])
            let size = text.size()
            text.draw(at: NSPoint(x: (s - size.width) / 2, y: s * 0.37 - size.height / 2))
            return true
        }
    }

    static func appIcon() -> NSImage { buddyIcon(.heart, color: Pastel.pink.nsColor) }

    static func pngData(_ image: NSImage, pixels: Int) -> Data? {
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8,
            samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
            bytesPerRow: 0, bitsPerPixel: 0) else { return nil }
        rep.size = NSSize(width: pixels, height: pixels)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        image.draw(in: NSRect(x: 0, y: 0, width: pixels, height: pixels))
        NSGraphicsContext.restoreGraphicsState()
        return rep.representation(using: .png, properties: [:])
    }

    static func writeIconset(to dir: URL) throws {
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let icon = appIcon()
        for base in [16, 32, 128, 256, 512] {
            for scale in [1, 2] {
                let name = scale == 1 ? "icon_\(base)x\(base).png" : "icon_\(base)x\(base)@2x.png"
                try pngData(icon, pixels: base * scale)?.write(to: dir.appendingPathComponent(name))
            }
        }
    }

    /// Sets (or with nil, resets) a folder's Finder icon. This doesn't rename or delete anything.
    @discardableResult
    static func setIcon(_ image: NSImage?, forFolder url: URL) -> Bool {
        var finalImage = image
        if let image, let data = pngData(image, pixels: 1024) {
            finalImage = NSImage(data: data)  // flatten to a bitmap so Finder stores it reliably
        }
        return NSWorkspace.shared.setIcon(finalImage, forFile: url.path, options: [])
    }
}
