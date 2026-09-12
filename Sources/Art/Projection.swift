import CoreGraphics
import Foundation

/// Maps the simulation's flat world onto a screen viewed from a tilted camera.
///
/// The camera looks down at the pitch from 25° off vertical rather than straight down. Two
/// consequences, and they are the whole of the effect:
///
/// - The **ground compresses** along the screen's vertical axis by `cos(tilt)`, so the circle
///   is drawn as an ellipse and the far side of it sits closer to the near side than its true
///   distance.
/// - Anything with **height projects upward** by `sin(tilt)`, so a post rises off its own base
///   and a figure floats above its own shadow. That gap is what reads as "standing up".
///
/// The simulation knows none of this. It is a flat 2D world and stays one — this is a change
/// of viewpoint, not of physics, which is why no rule, collision or bot decision is affected.
struct Projection {

    let centre: CGPoint
    let pointsPerMetre: CGFloat
    let tiltCos: CGFloat
    let tiltSin: CGFloat

    init(centre: CGPoint, pointsPerMetre: CGFloat, tilt: CGFloat) {
        self.centre = centre
        self.pointsPerMetre = pointsPerMetre
        self.tiltCos = cos(tilt)
        self.tiltSin = sin(tilt)
    }

    /// Where a world point appears, optionally lifted `height` metres off the ground.
    func point(_ world: Vec2, height: Double = 0) -> CGPoint {
        CGPoint(x: centre.x + CGFloat(world.x) * pointsPerMetre,
                y: centre.y + CGFloat(world.y) * pointsPerMetre * tiltCos
                            + CGFloat(height) * pointsPerMetre * tiltSin)
    }

    /// How far up the screen a height of `metres` carries something.
    func rise(_ metres: Double) -> CGFloat {
        CGFloat(metres) * pointsPerMetre * tiltSin
    }

    func length(_ metres: Double) -> CGFloat {
        CGFloat(metres) * pointsPerMetre
    }

    /// Ground footprints are circles in the world and ellipses on the screen.
    func footprint(radius metres: Double) -> CGSize {
        CGSize(width: length(metres) * 2, height: length(metres) * 2 * tiltCos)
    }

    /// A z-order that puts nearer things in front. Nearer means lower world `y`, so the term
    /// is negated; the span is bounded by the pitch, so this cannot collide with the layer
    /// constants it is added to.
    func depth(_ world: Vec2, within radius: Double) -> CGFloat {
        CGFloat((radius - world.y) / (radius * 2)) * 0.9
    }

    /// A path around the circle between two bearings, sampled and projected — `addArc` would
    /// draw a true circle, which is the wrong shape once the ground is compressed.
    func arc(radius metres: Double, from: Double, to: Double, steps: Int = 24) -> CGMutablePath {
        let path = CGMutablePath()
        for step in 0...steps {
            let bearing = from + (to - from) * Double(step) / Double(steps)
            let here = point(Vec2(angle: bearing, length: metres))
            if step == 0 { path.move(to: here) } else { path.addLine(to: here) }
        }
        return path
    }
}
