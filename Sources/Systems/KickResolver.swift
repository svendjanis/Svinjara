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

    /// The bearing a shot actually leaves on: the striker's facing, snapped onto a nearby open
    /// mouth when the shooter asked for help.
    ///
    /// Only mouths that are still open and are not the shooter's own count, and only the
    /// closest one within `aimAssistAngle` — the aid is for lining a goal up, never for
    /// choosing which goal to attack.
    static func aim(facing: Double,
                    from: Vec2,
                    shooter: Int,
                    assisted: Bool,
                    arena: ArenaGeometry,
                    tuning: Tuning) -> Double {
        guard assisted else { return facing }

        var best: (bearing: Double, offset: Double)?
        for goal in 0..<arena.goalCount where goal != shooter && arena.isOpen[goal] {
            let bearing = arena.aimBearing(from: from, at: goal)
            let offset = Angles.separation(facing, bearing)
            guard offset <= tuning.aimAssistAngle else { continue }
            if best == nil || offset < best!.offset { best = (bearing, offset) }
        }
        return best?.bearing ?? facing
    }

    /// Applies a released kick. The ball's existing velocity is **replaced**, not added to —
    /// otherwise kicking a ball that is already flying at you produces a 30 m/s rocket that
    /// nobody aimed. See `docs/RULES.md` §7.
    ///
    /// Every legal release is a shot. There used to be a "soft touch" below 15% charge, which
    /// meant a quick tap produced a 3 m/s nudge — so the most natural way to try to shoot
    /// produced the least shot-like result. Carrying the ball is what running into it does;
    /// the button is for hitting it.
    ///
    /// Returns the event, or nil if the kick was illegal and simply consumed the charge.
    static func strike(player: Int,
                       body: PlayerBody,
                       charge: Double,
                       assisted: Bool,
                       ball: inout BallState,
                       arena: ArenaGeometry,
                       tuning: Tuning) -> MatchEvent? {
        guard canStrike(body: body, ball: ball, tuning: tuning) else { return nil }

        let fraction = min(1, max(0, charge / tuning.kickChargeTime))
        let bearing = aim(facing: body.facing, from: ball.position, shooter: player,
                          assisted: assisted, arena: arena, tuning: tuning)

        ball.lastTouchedBy = player
        ball.velocity = Vec2(angle: bearing, length: speed(forCharge: charge, tuning: tuning))
        return .kicked(player: player, power: fraction)
    }

    /// The ball under your control, as opposed to struck by you.
    ///
    /// Body contact gives you one touch each time the two circles meet and nothing at all in
    /// between, so the ball spends most of its life deaf. Turn while it is rolling and it
    /// carries straight on, because nothing in the step ever takes speed *off* it in the
    /// direction you have stopped going — grip decides how hard you punt it and gather decides
    /// which way, and neither is any help once it has left your feet and you want it back on a
    /// new heading. That is what "no way to control it" was: not a weak touch, but a ball that
    /// only ever hears from you at the instant of a collision.
    ///
    /// So there is a zone a little wider than your own body inside which the ball is being
    /// shepherded rather than hit: its velocity is eased toward yours, which matches its pace
    /// to your pace and brings it round onto your heading at the same time. Three things keep
    /// that from being magnetism:
    ///
    /// - It falls off to nothing at the edge of the zone, so the ball is gathered by your feet
    ///   rather than by an aura. At touching distance it is at full strength.
    /// - It is weighted by how squarely the ball sits in front of your run, so a ball beside
    ///   you is not yours and one behind you is not yours at all. Running past a loose ball
    ///   still only brushes it, which is the same promise `dribbleGather` makes.
    /// - A ball above `controlCatchSpeed` is not captured, so a pass or a shot crosses the
    ///   zone untouched. You cannot stand in a lane and hoover up somebody else's ball.
    ///
    /// This deliberately does not set `lastTouchedBy`. Shepherding is not a touch, and the one
    /// thing that flag feeds — the goal announcement — should name whoever last actually hit
    /// the ball, not whoever it happened to roll past.
    ///
    /// Returns whether the ball was under control this step.
    @discardableResult
    static func resolveControl(body: PlayerBody,
                               ball: inout BallState,
                               dt: Double,
                               tuning: Tuning) -> Bool {
        guard ball.velocity.lengthSquared
                <= tuning.controlCatchSpeed * tuning.controlCatchSpeed else { return false }

        let delta = ball.position - body.position
        let distance = delta.length
        guard distance <= tuning.controlReach, distance > 1e-9 else { return false }

        let touching = tuning.touchDistance
        let nearness = distance <= touching
            ? 1
            : 1 - (distance - touching) / (tuning.controlReach - touching)

        // Where you are going, or where you are pointing when you are not going anywhere —
        // the same fallback `gathered` uses, for the same reason.
        let travel = body.velocity.lengthSquared > 1e-6 ? body.velocity.normalized
                                                        : Vec2(angle: body.facing)
        let frontness = max(0, travel.dot(delta / distance))

        let authority = nearness * frontness
        guard authority > 1e-9 else { return false }

        // Exponential, like every other rate in the simulation, so the result does not depend
        // on the step size.
        let ease = 1 - exp(-tuning.controlPull * authority * dt)
        ball.velocity += (body.velocity - ball.velocity) * ease
        return true
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
        // past it must not fling it sideways. And it transfers at less than 100%, so the ball
        // always settles back at your feet instead of running away from you.
        let carried = body.velocity.dot(normal) * tuning.dribbleGrip
        guard carried > 0 else { return true }

        // Where the push goes is not where the contact was.
        //
        // Two circles meeting send the ball off along the line between their centres, so a
        // touch taken a few centimetres off-line puts the ball further off-line still, and the
        // next touch compounds it. That divergence is what carrying the ball actually felt
        // like, and no amount of grip fixes it: grip sets how fast the ball leaves, not which
        // way. A foot points where its owner is running, so the push is steered toward the
        // direction of travel — by at most `dribbleGather`, so a player sprinting past a ball
        // still only clips it.
        let push = gathered(normal: normal, body: body, tuning: tuning)

        let along = ball.velocity.dot(push)
        if carried > along {
            ball.velocity += push * (carried - along)
        }
        return true
    }

    /// The contact normal, rotated toward the way the player is travelling.
    static func gathered(normal: Vec2, body: PlayerBody, tuning: Tuning) -> Vec2 {
        // Stood still, the only heading there is is the one the figure is pointing.
        let travel = body.velocity.lengthSquared > 1e-6 ? body.velocity.normalized
                                                        : Vec2(angle: body.facing)
        let offset = Angles.delta(from: normal.angle, to: travel.angle)
        let limit = tuning.dribbleGather
        return Vec2(angle: normal.angle + max(-limit, min(limit, offset)))
    }
}
