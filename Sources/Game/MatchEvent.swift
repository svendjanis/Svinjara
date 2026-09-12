import Foundation

/// Something the renderer, the HUD or the sound layer may want to react to. The simulation
/// returns these from every step; it never calls out to anything itself.
enum MatchEvent: Equatable {
    case kicked(player: Int, power: Double)
    case dashed(player: Int)
    /// A lunge that reached the ball and knocked it loose.
    case tackled(player: Int)
    case shoved(by: Int, victim: Int)
    case ballHitWall(speed: Double)
    case ballHitPost(speed: Double)

    /// `goal` is the player who let it in — the only thing the rules count. `scorer` is the
    /// last player to touch it, for the announcement line only.
    case conceded(goal: Int, scorer: Int?, ownGoal: Bool)

    /// The scorer took one back off their own tally. See `docs/RULES.md` §3.
    case redeemed(player: Int)

    /// `place` is the finishing position, so the first player out of five places 5th.
    case eliminated(player: Int, place: Int)

    /// The ball went nowhere for too long and was returned to the centre spot.
    case ballReset

    case resumed
    case finished(winner: Int)
}
