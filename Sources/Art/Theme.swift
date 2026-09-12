import SwiftUI
import UIKit

/// Colours and screen-space constants. The simulation works in metres and knows nothing about
/// any of this; `pointsPerMetre` is the single place the two worlds meet.
enum Theme {

    // MARK: Surface

    /// A little cooler and darker than photographic concrete, so white paint and saturated kits
    /// both stay legible on top of it.
    static let concrete = UIColor(red: 0.278, green: 0.282, blue: 0.286, alpha: 1)
    static let concreteHighlight = UIColor(red: 0.345, green: 0.349, blue: 0.353, alpha: 1)
    static let concreteShadow = UIColor(red: 0.204, green: 0.208, blue: 0.212, alpha: 1)

    /// Court paint is never actually white — it is scuffed and walked on.
    static let paint = UIColor(red: 0.878, green: 0.878, blue: 0.855, alpha: 1)

    /// A bricked-up goal reads as a repair, not as original surface.
    static let sealed = UIColor(red: 0.243, green: 0.227, blue: 0.220, alpha: 1)

    static let concreteBackdrop = Color(concrete)

    // MARK: Layout

    /// How far the camera is tilted off vertical. Straight down is 0.
    ///
    /// 35° is a deliberate compromise: enough that the pitch reads as a surface receding away
    /// from you and figures read as standing on it, little enough that the whole circle and all
    /// five goals stay legible at once — which is the thing the entire design rests on.
    ///
    /// 25° was tried first and is not worth having: it compresses the circle to a 0.91 aspect,
    /// which the eye simply reads as a circle. It also wastes the landscape width, since the
    /// pitch is height-bound — a steeper tilt shortens it and lets the whole thing be drawn
    /// larger.
    static let tilt: CGFloat = 35 * .pi / 180

    /// How far a figure floats above its own shadow, in metres. This gap is the only thing
    /// saying a player is standing rather than painted on the concrete.
    static let figureLift: Double = 1.0

    /// Post height in metres. Little goals, so little posts.
    static let postHeight: Double = 1.0

    /// How much of the view the pitch occupies. The game is landscape, so the binding
    /// constraint is the height: the circle fits it and the margins left and right carry the
    /// thumbs, which is the whole reason for landscape — controls beside the pitch, not on it.
    static let pitchScreenFraction: CGFloat = 0.92

    /// Figures are drawn larger than the disc that actually collides.
    ///
    /// At an honest 1.0 a player is about 16 pt across on a phone in landscape — roughly 2 mm,
    /// too small to read a kit or tell which way somebody is facing. The overlap this
    /// introduces is the standard arcade trade and nobody notices it; not being able to tell
    /// five players apart would be noticed immediately.
    static let figureScale: CGFloat = 1.7

    /// Converts simulation metres to screen points for a given view size and pitch radius.
    ///
    /// The tilt compresses the pitch vertically, so it needs less height than width — but the
    /// headroom it frees is spent on the HUD and on figures standing up, hence the tighter
    /// vertical fraction.
    static func pointsPerMetre(viewSize: CGSize, pitchRadius: Double) -> CGFloat {
        let diameter = CGFloat(pitchRadius * 2)
        let byWidth = viewSize.width * pitchScreenFraction / diameter
        let byHeight = viewSize.height * 0.86 / (diameter * cos(tilt))
        return min(byWidth, byHeight)
    }

    // MARK: Z-order

    enum Layer: CGFloat {
        case surface = 0
        case paintwork = 10
        case shadow = 20
        case player = 30
        /// Above the figures on purpose. Depth sorting says a nearer body should cover the
        /// ball, but losing track of the ball is the one thing the player cannot afford — and
        /// at this scale a ball drawn over somebody's shoulder costs nothing.
        case ball = 40
        case post = 50
        case effect = 60
        case hud = 100
    }
}
