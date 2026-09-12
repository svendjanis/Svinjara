import Foundation

/// Striking the ball, nudging it, and shouldering it along with your body.
enum KickResolver {

    /// The ball is at your feet: close enough, and in front of you rather than behind.
    static func canStrike(body: PlayerBody, ball: BallState, tuning: Tuning) -> Bool {
        let toBall = ball.position - body.position
        let distance = toBall.length
        guard distance <= tuning.kickReach else { return false }
        // Standing on top of it counts as in front of you — there is no sensible bearing.
        guard distance > 1e-9 else { return true }
        return Angles.separation(toBall.angle, body.facing) <= tuning.kickArc
    }

    /// Ball speed for a given held charge, linear between the min and max.
    static func speed(forCharge charge: Double, tuning: Tuning) -> Double {
        let fraction = min(1, max(0, charge / tuning.kickChargeTime))
        return tuning.kickMinSpeed + (tuning.kickMaxSpeed - tuning.kickMinSpeed) * fraction
    }

    /// Applies a released kick. The ball's existing velocity is **replaced**, not added to —
    /// otherwise kicking a ball that is already flying at you produces a 30 m/s rocket that
    /// nobody aimed. See `docs/RULES.md` §7.
    ///
    /// Returns the event, or nil if the kick was illegal and simply consumed the charge.
    static func strike(player: Int,
                       body: PlayerBody,
                       charge: Double,
                       ball: inout BallState,
                       tuning: Tuning) -> MatchEvent? {
        guard canStrike(body: body, ball: ball, tuning: tuning) else { return nil }

        let fraction = min(1, max(0, charge / tuning.kickChargeTime))
        ball.lastTouchedBy = player

        if fraction < tuning.softTouchThreshold {
            ball.velocity = Vec2(angle: body.facing, length: tuning.dribbleSpeed)
            return .softTouch(player: player)
        }

        ball.velocity = Vec2(angle: body.facing, length: speed(forCharge: charge, tuning: tuning))
        return .kicked(player: player, power: fraction)
    }

    /// A player's body running into the ball. This is what dribbling actually is: the ball is
    /// pushed off at the speed you were carrying into it, decays under rolling resistance,
    /// and you catch it again a step later. No possession flag, no magnetism.
    @discardableResult
    static func resolveBodyContact(player: Int,
                                   body: PlayerBody,
                                   ball: inout BallState,
                                   tuning: Tuning) -> Bool {
        let delta = ball.position - body.position
        let distance = delta.length
        let minimum = tuning.playerRadius + tuning.ballRadius
        guard distance < minimum else { return false }

        let normal = distance > 1e-9 ? delta / distance : Vec2(angle: body.facing)
        ball.position = body.position + normal * minimum
        ball.lastTouchedBy = player

        // Only the part of the player's motion that is going into the ball transfers; running
        // past it must not fling it sideways.
        let carried = body.velocity.dot(normal)
        guard carried > 0 else { return true }

        let along = ball.velocity.dot(normal)
        if carried > along {
            ball.velocity += normal * (carried - along)
        }
        return true
    }
}
