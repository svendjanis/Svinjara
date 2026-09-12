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

    /// How much of the view's shorter edge the pitch occupies. The remainder is the HUD strip
    /// above and the thumb controls below, which must not overlap the circle.
    static let pitchScreenFraction: CGFloat = 0.92

    /// Converts simulation metres to screen points for a given view size and pitch radius.
    static func pointsPerMetre(viewSize: CGSize, pitchRadius: Double) -> CGFloat {
        let shortEdge = min(viewSize.width, viewSize.height)
        return shortEdge * pitchScreenFraction / CGFloat(pitchRadius * 2)
    }

    // MARK: Z-order

    enum Layer: CGFloat {
        case surface = 0
        case paintwork = 10
        case shadow = 20
        case ball = 30
        case player = 40
        case post = 50
        case effect = 60
        case hud = 100
    }
}
