import SpriteKit
import UIKit

/// Draws the figures and the ball. Everything is code — the twenty national kits are a table
/// of colours, not twenty images. See `docs/ART_STYLE.md`.
enum KitPainter {

    /// One player, seen from directly overhead and facing **+x** (to the right), so a node can
    /// simply set `zRotation` to the figure's bearing.
    ///
    /// Drawn as shoulders and a head rather than a face: from this angle the only reliable cue
    /// for which way somebody is about to kick is the nose, so it is deliberately exaggerated.
    static func figure(nation: Nation, appearance: Appearance, diameter: CGFloat) -> UIImage {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 3
        format.opaque = false

        let size = CGSize(width: diameter, height: diameter)
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            let cg = context.cgContext
            let centre = CGPoint(x: diameter / 2, y: diameter / 2)

            // Shoulders are wider across than the body is front-to-back, which is what makes
            // an overhead figure read as a person rather than as a disc. The shirt has to be
            // the big shape: it is the only thing carrying which nation this is.
            let bodyLength = diameter * 0.54
            let bodyWidth = diameter * 0.76
            let body = CGRect(x: centre.x - bodyLength / 2, y: centre.y - bodyWidth / 2,
                              width: bodyLength, height: bodyWidth)

            drawBoots(cg, centre: centre, diameter: diameter, colour: nation.socks)

            cg.saveGState()
            cg.addEllipse(in: body)
            cg.clip()
            cg.setFillColor(nation.shirt.uiColor.cgColor)
            cg.fill(body)
            drawPattern(cg, nation: nation, in: body)
            cg.restoreGState()

            // A dark rim separates a pale kit from pale concrete.
            cg.setStrokeColor(UIColor.black.withAlphaComponent(0.35).cgColor)
            cg.setLineWidth(diameter * 0.025)
            cg.strokeEllipse(in: body)

            drawHead(cg, centre: centre, diameter: diameter, appearance: appearance)
        }
    }

    private static func drawPattern(_ cg: CGContext, nation: Nation, in body: CGRect) {
        let trim = nation.trim.uiColor.cgColor
        cg.setFillColor(trim)

        switch nation.pattern {
        case .solid:
            break

        case .stripes:
            // Vertical stripes on a standing player run across the body from overhead.
            let count = 4
            let width = body.width / CGFloat(count * 2 - 1)
            for index in stride(from: 0, to: count, by: 1) {
                let x = body.minX + CGFloat(index) * width * 2
                cg.fill(CGRect(x: x, y: body.minY, width: width, height: body.height))
            }

        case .checks:
            let squares = 4
            let w = body.width / CGFloat(squares)
            let h = body.height / CGFloat(squares)
            for row in 0..<squares {
                for column in 0..<squares where (row + column) % 2 == 0 {
                    cg.fill(CGRect(x: body.minX + CGFloat(column) * w,
                                   y: body.minY + CGFloat(row) * h,
                                   width: w, height: h))
                }
            }

        case .sash:
            cg.saveGState()
            cg.move(to: CGPoint(x: body.minX, y: body.minY))
            cg.addLine(to: CGPoint(x: body.maxX, y: body.midY - body.height * 0.12))
            cg.addLine(to: CGPoint(x: body.maxX, y: body.midY + body.height * 0.14))
            cg.addLine(to: CGPoint(x: body.minX, y: body.minY + body.height * 0.42))
            cg.closePath()
            cg.fillPath()
            cg.restoreGState()
        }
    }

    private static func drawHead(_ cg: CGContext, centre: CGPoint, diameter: CGFloat,
                                 appearance: Appearance) {
        // Deliberately small against the shoulders. Drawn any larger it covers the shirt, and
        // the shirt is the whole identity.
        let headRadius = diameter * 0.17
        let head = CGRect(x: centre.x - headRadius, y: centre.y - headRadius,
                          width: headRadius * 2, height: headRadius * 2)

        cg.setFillColor(appearance.skin.uiColor.cgColor)
        cg.fillEllipse(in: head)

        // Hair covers the back of the head, so its asymmetry is what makes facing readable.
        if appearance.style != .bald {
            cg.saveGState()
            cg.addEllipse(in: head)
            cg.clip()
            cg.setFillColor(appearance.hair.uiColor.cgColor)

            let coverage: CGFloat
            switch appearance.style {
            case .short: coverage = 0.62
            case .fade: coverage = 0.48
            case .curly: coverage = 0.72
            case .long: coverage = 0.82
            case .bald: coverage = 0
            }
            cg.fill(CGRect(x: head.minX, y: head.minY,
                           width: head.width * coverage, height: head.height))

            if appearance.style == .curly {
                // A scalloped fringe reads as curls at this size; anything finer is lost.
                cg.setFillColor(appearance.hair.uiColor.cgColor)
                for index in 0..<4 {
                    let y = head.minY + head.height * (0.1 + 0.25 * CGFloat(index))
                    cg.fillEllipse(in: CGRect(x: head.minX + head.width * coverage - headRadius * 0.28,
                                              y: y, width: headRadius * 0.5, height: headRadius * 0.5))
                }
            }
            cg.restoreGState()
        }

        cg.setStrokeColor(UIColor.black.withAlphaComponent(0.28).cgColor)
        cg.setLineWidth(diameter * 0.02)
        cg.strokeEllipse(in: head)

        // The nose. Exaggerated on purpose — from overhead it is the only dependable cue for
        // which way a player is about to kick.
        cg.setFillColor(appearance.skin.uiColor.darkened(by: 0.12).cgColor)
        cg.move(to: CGPoint(x: centre.x + headRadius * 0.72, y: centre.y - headRadius * 0.34))
        cg.addLine(to: CGPoint(x: centre.x + headRadius * 1.34, y: centre.y))
        cg.addLine(to: CGPoint(x: centre.x + headRadius * 0.72, y: centre.y + headRadius * 0.34))
        cg.closePath()
        cg.fillPath()
    }

    private static func drawBoots(_ cg: CGContext, centre: CGPoint, diameter: CGFloat,
                                  colour: RGB) {
        cg.setFillColor(colour.uiColor.darkened(by: 0.25).cgColor)
        let bootLength = diameter * 0.20
        let bootWidth = diameter * 0.12
        for side in [-1.0, 1.0] {
            cg.fillEllipse(in: CGRect(x: centre.x + diameter * 0.06,
                                      y: centre.y + CGFloat(side) * diameter * 0.34 - bootWidth / 2,
                                      width: bootLength, height: bootWidth))
        }
    }

    /// The ball: white, black patches, and a hard little shadow so it can be found in a scrap.
    static func ball(diameter: CGFloat) -> UIImage {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 3
        format.opaque = false

        return UIGraphicsImageRenderer(size: CGSize(width: diameter, height: diameter),
                                       format: format).image { context in
            let cg = context.cgContext
            let rect = CGRect(x: 0, y: 0, width: diameter, height: diameter)

            cg.setFillColor(UIColor(white: 0.97, alpha: 1).cgColor)
            cg.fillEllipse(in: rect)

            cg.saveGState()
            cg.addEllipse(in: rect)
            cg.clip()
            cg.setFillColor(UIColor(white: 0.12, alpha: 1).cgColor)
            let patch = diameter * 0.30
            cg.fillEllipse(in: CGRect(x: diameter * 0.35, y: diameter * 0.35,
                                      width: patch, height: patch))
            for angle in stride(from: 0.0, to: Angles.tau, by: Angles.tau / 5) {
                let r = diameter * 0.36
                let small = diameter * 0.19
                cg.fillEllipse(in: CGRect(x: diameter / 2 + CGFloat(cos(angle)) * r - small / 2,
                                          y: diameter / 2 + CGFloat(sin(angle)) * r - small / 2,
                                          width: small, height: small))
            }
            cg.restoreGState()

            cg.setStrokeColor(UIColor(white: 0.2, alpha: 0.5).cgColor)
            cg.setLineWidth(diameter * 0.06)
            cg.strokeEllipse(in: rect.insetBy(dx: diameter * 0.03, dy: diameter * 0.03))
        }
    }
}

extension RGB {
    var uiColor: UIColor { UIColor(red: r, green: g, blue: b, alpha: 1) }
}

extension UIColor {
    func darkened(by amount: CGFloat) -> UIColor {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return UIColor(red: max(0, r - amount), green: max(0, g - amount),
                       blue: max(0, b - amount), alpha: a)
    }
}
