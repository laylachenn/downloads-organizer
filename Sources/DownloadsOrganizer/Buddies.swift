import AppKit

/// Original "mochi buddy" characters: a round little mochi peeking over a pastel folder, each with its own accessory.
enum Buddy: String, CaseIterable, Identifiable {
    case heart, bow, flower, headphones, star, sprout, crown

    var id: String { rawValue }
    var label: String {
        switch self {
        case .heart: "💗 Heart buddy"
        case .bow: "🎀 Bow buddy"
        case .flower: "🌼 Flower buddy"
        case .headphones: "🎧 Music buddy"
        case .star: "⭐️ Star buddy"
        case .sprout: "🌱 Sprout buddy"
        case .crown: "👑 Crown buddy"
        }
    }
}

extension IconMaker {
    static func buddyIcon(_ buddy: Buddy, color: NSColor) -> NSImage {
        NSImage(size: NSSize(width: 512, height: 512), flipped: false) { rect in
            let s = rect.width
            func r(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> NSRect {
                NSRect(x: x * s, y: y * s, width: w * s, height: h * s)
            }
            func p(_ x: CGFloat, _ y: CGFloat) -> NSPoint { NSPoint(x: x * s, y: y * s) }
            func oval(_ rect: NSRect, _ fill: NSColor, stroke: NSColor? = nil, width: CGFloat = 0.012) {
                let path = NSBezierPath(ovalIn: rect)
                fill.setFill(); path.fill()
                if let stroke { stroke.setStroke(); path.lineWidth = s * width; path.stroke() }
            }

            let back = color.blended(withFraction: 0.18, of: .systemPink) ?? color
            let ink = NSColor(red: 0.45, green: 0.28, blue: 0.32, alpha: 1)
            let mochi = NSColor(red: 1.0, green: 0.975, blue: 0.95, alpha: 1)
            let hotPink = NSColor(red: 0.95, green: 0.45, blue: 0.65, alpha: 1)
            let gold = NSColor(red: 1.0, green: 0.82, blue: 0.35, alpha: 1)

            // folder back + tab
            back.setFill()
            NSBezierPath(roundedRect: r(0.08, 0.40, 0.32, 0.12), xRadius: s * 0.04, yRadius: s * 0.04).fill()
            NSBezierPath(roundedRect: r(0.08, 0.08, 0.84, 0.40), xRadius: s * 0.06, yRadius: s * 0.06).fill()

            // accessories that sit behind the head
            if buddy == .headphones {
                let band = NSBezierPath()
                band.appendArc(withCenter: p(0.5, 0.52), radius: s * 0.235, startAngle: 15, endAngle: 165)
                hotPink.setStroke(); band.lineWidth = s * 0.035; band.lineCapStyle = .round; band.stroke()
            }

            // mochi body
            oval(r(0.25, 0.28, 0.50, 0.44), mochi, stroke: ink)

            // face
            oval(r(0.395, 0.55, 0.04, 0.055), ink)
            oval(r(0.565, 0.55, 0.04, 0.055), ink)
            oval(r(0.405, 0.582, 0.014, 0.017), .white)
            oval(r(0.575, 0.582, 0.014, 0.017), .white)
            oval(r(0.33, 0.505, 0.075, 0.042), hotPink.withAlphaComponent(0.45))
            oval(r(0.595, 0.505, 0.075, 0.042), hotPink.withAlphaComponent(0.45))
            let mouth = NSBezierPath()
            mouth.move(to: p(0.475, 0.535))
            mouth.curve(to: p(0.525, 0.535), controlPoint1: p(0.485, 0.505), controlPoint2: p(0.515, 0.505))
            ink.setStroke(); mouth.lineWidth = s * 0.01; mouth.lineCapStyle = .round; mouth.stroke()

            // accessory on top
            switch buddy {
            case .heart:
                let c = p(0.5, 0.745), w = s * 0.045
                let heart = NSBezierPath()
                heart.move(to: c)
                heart.curve(to: NSPoint(x: c.x - w * 1.6, y: c.y + w * 1.5),
                            controlPoint1: NSPoint(x: c.x - w * 0.6, y: c.y + w * 0.4), controlPoint2: NSPoint(x: c.x - w * 1.6, y: c.y + w * 0.8))
                heart.curve(to: NSPoint(x: c.x, y: c.y + w * 1.6),
                            controlPoint1: NSPoint(x: c.x - w * 1.6, y: c.y + w * 2.3), controlPoint2: NSPoint(x: c.x - w * 0.3, y: c.y + w * 2.3))
                heart.curve(to: NSPoint(x: c.x + w * 1.6, y: c.y + w * 1.5),
                            controlPoint1: NSPoint(x: c.x + w * 0.3, y: c.y + w * 2.3), controlPoint2: NSPoint(x: c.x + w * 1.6, y: c.y + w * 2.3))
                heart.curve(to: c,
                            controlPoint1: NSPoint(x: c.x + w * 1.6, y: c.y + w * 0.8), controlPoint2: NSPoint(x: c.x + w * 0.6, y: c.y + w * 0.4))
                hotPink.setFill(); heart.fill()
                NSColor.white.withAlphaComponent(0.6).setFill()
                NSBezierPath(ovalIn: NSRect(x: c.x - w * 1.05, y: c.y + w * 1.35, width: w * 0.45, height: w * 0.35)).fill()
            case .bow:
                let wings = NSBezierPath()
                wings.move(to: p(0.64, 0.71)); wings.line(to: p(0.555, 0.765)); wings.line(to: p(0.565, 0.66)); wings.close()
                wings.move(to: p(0.64, 0.71)); wings.line(to: p(0.725, 0.765)); wings.line(to: p(0.715, 0.66)); wings.close()
                hotPink.setFill(); wings.fill()
                hotPink.setStroke(); wings.lineWidth = s * 0.03; wings.lineJoinStyle = .round; wings.stroke()
                oval(r(0.615, 0.685, 0.05, 0.05), hotPink.blended(withFraction: 0.25, of: .black) ?? hotPink)
            case .flower:
                let center = p(0.5, 0.765)
                for i in 0..<5 {
                    let a = CGFloat(i) * 2 * .pi / 5 + .pi / 2
                    let c = NSPoint(x: center.x + cos(a) * s * 0.045, y: center.y + sin(a) * s * 0.045)
                    oval(NSRect(x: c.x - s * 0.035, y: c.y - s * 0.035, width: s * 0.07, height: s * 0.07), .white, stroke: hotPink, width: 0.006)
                }
                oval(NSRect(x: center.x - s * 0.028, y: center.y - s * 0.028, width: s * 0.056, height: s * 0.056), gold)
            case .headphones:
                oval(r(0.205, 0.47, 0.075, 0.12), hotPink, stroke: ink, width: 0.008)
                oval(r(0.72, 0.47, 0.075, 0.12), hotPink, stroke: ink, width: 0.008)
            case .star:
                let star = NSBezierPath()
                let c = p(0.63, 0.735)
                for i in 0..<10 {
                    let rad = s * (i.isMultiple(of: 2) ? 0.075 : 0.032)
                    let a = CGFloat(i) * .pi / 5 + .pi / 2
                    let pt = NSPoint(x: c.x + cos(a) * rad, y: c.y + sin(a) * rad)
                    i == 0 ? star.move(to: pt) : star.line(to: pt)
                }
                star.close()
                gold.setFill(); star.fill()
                ink.setStroke(); star.lineWidth = s * 0.006; star.lineJoinStyle = .round; star.stroke()
            case .sprout:
                let green = NSColor(red: 0.45, green: 0.78, blue: 0.5, alpha: 1)
                let stem = NSBezierPath()
                stem.move(to: p(0.5, 0.715)); stem.line(to: p(0.5, 0.775))
                green.setStroke(); stem.lineWidth = s * 0.014; stem.lineCapStyle = .round; stem.stroke()
                for dir in [-1.0, 1.0] as [CGFloat] {
                    let leaf = NSBezierPath()
                    leaf.move(to: p(0.5, 0.775))
                    leaf.curve(to: p(0.5 + dir * 0.10, 0.80), controlPoint1: p(0.5 + dir * 0.03, 0.84), controlPoint2: p(0.5 + dir * 0.09, 0.84))
                    leaf.curve(to: p(0.5, 0.775), controlPoint1: p(0.5 + dir * 0.08, 0.77), controlPoint2: p(0.5 + dir * 0.03, 0.76))
                    green.setFill(); leaf.fill()
                }
            case .crown:
                let crown = NSBezierPath()
                for (i, pt) in [(0.41, 0.70), (0.40, 0.785), (0.455, 0.745), (0.5, 0.80), (0.545, 0.745), (0.60, 0.785), (0.59, 0.70)].enumerated() {
                    i == 0 ? crown.move(to: p(pt.0, pt.1)) : crown.line(to: p(pt.0, pt.1))
                }
                crown.close()
                gold.setFill(); crown.fill()
                ink.setStroke(); crown.lineWidth = s * 0.008; crown.lineJoinStyle = .round; crown.stroke()
                oval(r(0.488, 0.725, 0.024, 0.024), hotPink)
            }

            // folder front, with the buddy's little hands holding the edge
            NSGraphicsContext.saveGraphicsState()
            let shadow = NSShadow()
            shadow.shadowColor = NSColor.black.withAlphaComponent(0.15)
            shadow.shadowOffset = NSSize(width: 0, height: -s * 0.01)
            shadow.shadowBlurRadius = s * 0.02
            shadow.set()
            color.setFill()
            NSBezierPath(roundedRect: r(0.08, 0.06, 0.84, 0.38), xRadius: s * 0.06, yRadius: s * 0.06).fill()
            NSGraphicsContext.restoreGraphicsState()
            NSColor.white.withAlphaComponent(0.45).setFill()
            NSBezierPath(roundedRect: r(0.13, 0.37, 0.74, 0.03), xRadius: s * 0.015, yRadius: s * 0.015).fill()
            oval(r(0.30, 0.405, 0.09, 0.065), mochi, stroke: ink, width: 0.01)
            oval(r(0.61, 0.405, 0.09, 0.065), mochi, stroke: ink, width: 0.01)
            return true
        }
    }
}
