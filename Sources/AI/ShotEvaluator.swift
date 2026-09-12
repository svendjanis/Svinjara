import Foundation

/// Picks which rival to punish, and where in their mouth to put it.
///
/// This is what makes greed cost something: the ranking rewards a goal whose owner has
/// wandered off it, so the moment you step up to attack, four opponents notice.
enum ShotEvaluator {

    struct Shot: Equatable {
        let goal: Int
        /// The point in the mouth being aimed at, not the mouth centre — a blocked lane is
        /// often open to one side of it.
        let target: Vec2
        let score: Double
    }

    /// Fractions across the mouth to consider, from one post to the other. The extremes stop
    /// short of the posts themselves, since a shot at a post is a shot at a post.
    private static let aimFractions: [Double] = [0, -0.6, 0.6, -0.3, 0.3]

    /// The best shot available to `shooter` from the ball's current position, or nil if every
    /// rival is already out.
    ///
    /// `noise` is not decoration. Candidates are scanned in player-index order, so any exact
    /// tie would always fall to the lowest-index rival — and measured over 40 matches that
    /// handed slot 0 a third more goals against than its fair share while slot 3 got a third
    /// fewer. A small random tiebreak makes the ranking positionally neutral and stays
    /// reproducible, because the generator is seeded.
    static func best(for shooter: Int,
                     state: MatchState,
                     tuning: Tuning,
                     noise: inout SeededRandom) -> Shot? {
        var best: Shot?

        for rival in state.players where rival.isAlive && rival.index != shooter {
            for fraction in aimFractions {
                let target = aimPoint(goal: rival.index, fraction: fraction, state: state)
                let score = rate(shooter: shooter, keeper: rival, target: target,
                                 state: state, tuning: tuning)
                    + noise.double(in: -0.05...0.05)
                if best == nil || score > best!.score {
                    best = Shot(goal: rival.index, target: target, score: score)
                }
            }
        }
        return best
    }

    private static func aimPoint(goal: Int, fraction: Double, state: MatchState) -> Vec2 {
        let bearing = state.arena.bearings[goal] + fraction * state.arena.mouthHalfAngle
        return Vec2(angle: bearing, length: state.arena.radius)
    }

    private static func rate(shooter: Int,
                             keeper: PlayerState,
                             target: Vec2,
                             state: MatchState,
                             tuning: Tuning) -> Double {
        let from = state.ball.position
        let distance = from.distance(to: target)

        // Close is better, but only up to a point — being on top of a goal leaves no angle.
        let range = 1 - min(1, distance / (state.arena.radius * 2))

        // An owner stood off their own line is the invitation. Deliberately not clamped at 1:
        // saturating it made most keepers score identically and turned the ranking into a
        // coin-toss decided by iteration order.
        let mouth = state.arena.mouthCentre(of: keeper.index)
        let exposure = keeper.body.position.distance(to: mouth) / state.arena.radius

        // Anything in the way — a rival's body or a post — is what actually decides it.
        let blocked = laneBlockage(from: from, to: target, ignoring: [shooter, keeper.index],
                                   state: state, tuning: tuning)

        return range * 0.8 + exposure * 1.4 - blocked * 2.2
    }

    /// How obstructed the line from `from` to `to` is, `0` clear and `1` fully blocked.
    /// Posts count: they frame every mouth, so a shot at a sharp angle is genuinely harder.
    static func laneBlockage(from: Vec2,
                             to: Vec2,
                             ignoring: [Int],
                             state: MatchState,
                             tuning: Tuning) -> Double {
        var worst = 0.0

        for player in state.players where player.isAlive && !ignoring.contains(player.index) {
            let clearance = tuning.playerRadius + tuning.ballRadius
            let distance = distanceFromSegment(player.body.position, from, to)
            worst = max(worst, max(0, 1 - distance / (clearance * 2.2)))
        }

        for post in state.arena.activePosts {
            let clearance = state.arena.postRadius + tuning.ballRadius
            let distance = distanceFromSegment(post, from, to)
            worst = max(worst, max(0, 1 - distance / (clearance * 1.6)))
        }

        return min(1, worst)
    }

    /// Perpendicular distance from a point to a line segment.
    static func distanceFromSegment(_ point: Vec2, _ a: Vec2, _ b: Vec2) -> Double {
        let along = b - a
        let lengthSquared = along.lengthSquared
        guard lengthSquared > 1e-12 else { return point.distance(to: a) }
        let t = min(1, max(0, (point - a).dot(along) / lengthSquared))
        return point.distance(to: a + along * t)
    }
}
