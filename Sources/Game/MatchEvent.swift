import Foundation

/// Something the renderer, the HUD or the sound layer may want to react to. The simulation
/// returns these from every step; it never calls out to anything itself.
enum MatchEvent: Equatable {
    case kicked(player: Int, power: Double)
    case softTouch(player: Int)
    case dashed(player: Int)
    case shoved(by: Int, victim: Int)
    case ballHitWall(speed: Double)
    case ballHitPost(speed: Double)

    /// `goal` is the player who let it in — the only thing the rules count. `scorer` is the
    /// last player to touch it, for the announcement line only.
    case conceded(goal: Int, scorer: Int?, ownGoal: Bool)

    /// `place` is the finishing position, so the first player out of five places 5th.
    case eliminated(player: Int, place: Int)

    /// The ball went nowhere for too long and was returned to the centre spot.
    case ballReset

    case resumed
    case finished(winner: Int)
}
