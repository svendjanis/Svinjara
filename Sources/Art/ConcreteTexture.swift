import SpriteKit
import UIKit

/// The court surface, drawn once into a texture at load.
///
/// Concrete seen from overhead on a bright day: flat, slightly dirty, no gradients pretending
/// to be 3D. The noise is seeded, so the same court is drawn every run — which matters when
/// comparing screenshots.
enum ConcreteTexture {

    static func make(size: CGSize, seed: UInt64 = 7, depthShading: Bool = true) -> SKTexture {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 2
        format.opaque = true

        let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
            let cg = context.cgContext
            var rng = SeededRandom(seed: seed)

            cg.setFillColor(Theme.concrete.cgColor)
            cg.fill(CGRect(origin: .zero, size: size))

            // Large soft blotches first, so the surface does not read as one flat wash.
            for _ in 0..<26 {
                let radius = CGFloat(rng.double(in: 60...190))
                let centre = CGPoint(x: CGFloat(rng.double(in: 0...Double(size.width))),
                                     y: CGFloat(rng.double(in: 0...Double(size.height))))
                let lighter = rng.bool(chance: 0.5)
                cg.setFillColor((lighter ? Theme.concreteHighlight : Theme.concreteShadow)
                    .withAlphaComponent(CGFloat(rng.double(in: 0.05...0.13))).cgColor)
                cg.fillEllipse(in: CGRect(x: centre.x - radius, y: centre.y - radius,
                                          width: radius * 2, height: radius * 2))
            }

            // Fine value noise on a coarse grid. Per-pixel would be invisible at this scale
            // and enormously slower.
            let cell: CGFloat = 3
            var y: CGFloat = 0
            while y < size.height {
                var x: CGFloat = 0
                while x < size.width {
                    let shade = rng.double(in: -0.05...0.05)
                    cg.setFillColor(UIColor(white: 0.5 + CGFloat(shade), alpha: 0.16).cgColor)
                    cg.fill(CGRect(x: x, y: y, width: cell, height: cell))
                    x += cell
                }
                y += cell
            }

            // Aggregate: the little stones in the mix.
            for _ in 0..<Int(size.width * size.height / 900) {
                let radius = CGFloat(rng.double(in: 0.6...2.1))
                let point = CGPoint(x: CGFloat(rng.double(in: 0...Double(size.width))),
                                    y: CGFloat(rng.double(in: 0...Double(size.height))))
                cg.setFillColor((rng.bool(chance: 0.6) ? Theme.concreteShadow : Theme.concreteHighlight)
                    .withAlphaComponent(CGFloat(rng.double(in: 0.25...0.6))).cgColor)
                cg.fillEllipse(in: CGRect(x: point.x, y: point.y, width: radius * 2, height: radius * 2))
            }

            // The far side of a tilted surface catches less light and sits in more haze. It is
            // a slight effect on purpose — overdone it reads as a spotlight in the middle of
            // the court rather than as distance.
            if depthShading, let shade = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: [Theme.concreteShadow.withAlphaComponent(0.30).cgColor,
                         Theme.concreteShadow.withAlphaComponent(0.0).cgColor,
                         Theme.concreteHighlight.withAlphaComponent(0.10).cgColor] as CFArray,
                locations: [0, 0.55, 1]) {
                cg.drawLinearGradient(shade,
                                      start: CGPoint(x: 0, y: 0),
                                      end: CGPoint(x: 0, y: size.height),
                                      options: [])
            }

            // A few hairline cracks wandering across the slab.
            cg.setLineCap(.round)
            for _ in 0..<5 {
                var point = CGPoint(x: CGFloat(rng.double(in: 0...Double(size.width))),
                                    y: CGFloat(rng.double(in: 0...Double(size.height))))
                var heading = rng.double(in: -Double.pi ... .pi)
                cg.setStrokeColor(Theme.concreteShadow.withAlphaComponent(0.55).cgColor)
                cg.setLineWidth(CGFloat(rng.double(in: 0.7...1.4)))
                cg.move(to: point)
                for _ in 0..<Int(rng.int(in: 14...34)) {
                    heading += rng.double(in: -0.45...0.45)
                    point = CGPoint(x: point.x + CGFloat(cos(heading)) * 14,
                                    y: point.y + CGFloat(sin(heading)) * 14)
                    cg.addLine(to: point)
                }
                cg.strokePath()
            }
        }

        let texture = SKTexture(image: image)
        texture.filteringMode = .linear
        return texture
    }
}
