import SpriteKit
import UIKit

/// The white circle, painted on the concrete.
///
/// Drawn into its own transparent texture rather than stroked as a shape node, because court
/// paint is not a vector-perfect ring: it is walked on, so it wants gaps, thin spots and a
/// slightly wandering edge. One texture buys all of that and costs one draw.
enum CourtPaint {

    static func make(size: CGSize, centre: CGPoint, radius: CGFloat, lineWidth: CGFloat,
                     seed: UInt64 = 19) -> SKTexture {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 2
        format.opaque = false

        let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
            let cg = context.cgContext
            var rng = SeededRandom(seed: seed)
            cg.setLineCap(.round)

            let segments = 360
            for index in 0..<segments {
                // Occasional missing segment: paint wears off where people stand.
                guard !rng.bool(chance: 0.06) else { continue }

                let span: Double = Angles.tau / Double(segments)
                let from: Double = Double(index) * span
                let to: Double = from + span * 1.6
                let wobble = CGFloat(rng.double(in: -0.45...0.45))
                let alpha = CGFloat(rng.double(in: 0.55...1.0))

                cg.setStrokeColor(Theme.paint.withAlphaComponent(alpha).cgColor)
                cg.setLineWidth(lineWidth * CGFloat(rng.double(in: 0.82...1.1)))
                cg.addArc(center: centre, radius: radius + wobble,
                          startAngle: CGFloat(from), endAngle: CGFloat(to), clockwise: false)
                cg.strokePath()
            }

            // The centre spot.
            cg.setFillColor(Theme.paint.withAlphaComponent(0.8).cgColor)
            let spot = lineWidth * 1.6
            cg.fillEllipse(in: CGRect(x: centre.x - spot / 2, y: centre.y - spot / 2,
                                      width: spot, height: spot))
        }

        let texture = SKTexture(image: image)
        texture.filteringMode = .linear
        return texture
    }
}
