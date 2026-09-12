import SpriteKit
import UIKit

/// The white circle, painted on the concrete.
///
/// Drawn into its own transparent texture rather than stroked as a shape node, because court
/// paint is not a vector-perfect ring: it is walked on, so it wants gaps, thin spots and a
/// slightly wandering edge. One texture buys all of that and costs one draw.
enum CourtPaint {

    static func make(size: CGSize, projection: Projection, radius: Double, lineWidth: CGFloat,
                     seed: UInt64 = 19) -> SKTexture {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 2
        format.opaque = false

        let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
            let cg = context.cgContext
            var rng = SeededRandom(seed: seed)
            cg.setLineCap(.round)

            // Drawn as short projected segments rather than with `addArc`, for two reasons:
            // the tilted ground makes the line an ellipse, and stroking each piece separately
            // is what allows the gaps, thin spots and wander that real court paint has.
            let segments = 360
            for index in 0..<segments {
                // Occasional missing segment: paint wears off where people stand.
                guard !rng.bool(chance: 0.06) else { continue }

                let span: Double = Angles.tau / Double(segments)
                let from: Double = Double(index) * span
                let to: Double = from + span * 1.6
                let wobble = rng.double(in: -0.02...0.02)
                let alpha = CGFloat(rng.double(in: 0.55...1.0))

                cg.setStrokeColor(Theme.paint.withAlphaComponent(alpha).cgColor)
                cg.setLineWidth(lineWidth * CGFloat(rng.double(in: 0.82...1.1)))
                cg.setLineCap(.round)
                cg.move(to: projection.point(Vec2(angle: from, length: radius + wobble)))
                cg.addLine(to: projection.point(Vec2(angle: to, length: radius + wobble)))
                cg.strokePath()
            }

            // The centre spot, flattened onto the ground like everything else.
            cg.setFillColor(Theme.paint.withAlphaComponent(0.8).cgColor)
            let spot = lineWidth * 1.6
            let middle = projection.point(.zero)
            cg.fillEllipse(in: CGRect(x: middle.x - spot / 2,
                                      y: middle.y - spot * projection.tiltCos / 2,
                                      width: spot, height: spot * projection.tiltCos))
        }

        let texture = SKTexture(image: image)
        texture.filteringMode = .linear
        return texture
    }
}
