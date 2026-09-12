import Foundation

/// Small helpers shared by the bot's states.
enum Steering {

    /// A move vector that walks toward a point and eases off as it arrives, so a bot settles
    /// on its spot instead of oscillating across it at full tilt.
    static func seek(from: Vec2, to: Vec2, slowingRadius: Double = 0.9) -> Vec2 {
        let delta = to - from
        let distance = delta.length
        guard distance > 0.06 else { return .zero }
        return delta.normalized * min(1, distance / slowingRadius)
    }

    /// Pulls a target point back inside the pitch. A bot asked to stand on a spot outside the
    /// line would press itself against the paint for ever, which looks broken and defends
    /// nothing.
    static func inside(_ point: Vec2, arena: ArenaGeometry, bodyRadius: Double) -> Vec2 {
        let limit = arena.radius - bodyRadius - 0.02
        guard point.length > limit else { return point }
        return point.normalized * limit
    }

    /// Where to stand in order to strike the ball toward `aim`, and the aim that makes that
    /// spot reachable.
    ///
    /// Standing behind the ball means standing between it and where you want it to go — but
    /// for a ball resting against the line, "behind it" is outside the pitch. Left uncorrected
    /// the bot walks at a spot it can never occupy, never gets close enough to switch to
    /// shooting, and simply leans on the ball for the rest of the match. Two bots did exactly
    /// that against a bricked-up goal and the match never ended.
    ///
    /// So the aim is rotated toward the outward radial only as far as it must be: near the
    /// line you can only strike the ball outward, which knocks it into the paint and back into
    /// play. That is what a person would do too.
    static func approach(ball: Vec2,
                         aim: Vec2,
                         arena: ArenaGeometry,
                         bodyRadius: Double,
                         ballRadius: Double) -> (aim: Vec2, spot: Vec2) {
        let standOff = bodyRadius + ballRadius
        let limit = arena.radius - bodyRadius - 0.02

        var chosenAim = aim.normalized
        var spot = ball - chosenAim * standOff
        guard spot.length > limit else { return (chosenAim, spot) }

        let distance = ball.length
        guard distance > 1e-6 else { return (chosenAim, inside(spot, arena: arena, bodyRadius: bodyRadius)) }

        // |ball − aim·s| ≤ limit  ⇔  cos∠(outward, aim) ≥ (|ball|² + s² − limit²) / (2·s·|ball|)
        let cosLimit = (ball.lengthSquared + standOff * standOff - limit * limit)
            / (2 * standOff * distance)
        let outward = ball.normalized

        if cosLimit >= 1 {
            chosenAim = outward
        } else if cosLimit > -1 {
            let widest = acos(cosLimit)
            let offset = Angles.delta(from: outward.angle, to: chosenAim.angle)
            chosenAim = Vec2(angle: outward.angle + max(-widest, min(widest, offset)))
        }

        spot = ball - chosenAim * standOff
        return (chosenAim, inside(spot, arena: arena, bodyRadius: bodyRadius))
    }
}
