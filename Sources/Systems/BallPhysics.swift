import Foundation

/// The ball, reduced to what the solver needs.
struct BallState: Equatable {
    var position: Vec2 = .zero
    var velocity: Vec2 = .zero

    /// Who touched it last. Used only for the goal announcement — it has no effect on the
    /// rules, because only conceding is counted. See `docs/RULES.md` §3.
    var lastTouchedBy: Int?

    var isAtRest: Bool { velocity == .zero }
}

enum BallPhysics {

    /// Advances the ball one fixed slice and returns where it started, which the caller needs
    /// for the swept post test and the goal-crossing solve.
    @discardableResult
    static func integrate(_ ball: inout BallState, dt: Double, tuning: Tuning) -> Vec2 {
        let previous = ball.position

        // Exponential decay, not a constant subtraction. A constant subtraction is step-size
        // dependent — which determinism forbids — and makes a slow ball stop abruptly instead
        // of trickling to a halt.
        ball.velocity *= exp(-tuning.ballDamping * dt)

        // Below the rest threshold just stop it, so it never creeps across the pitch at
        // 0.001 m/s for the remainder of the match.
        if ball.velocity.lengthSquared < tuning.ballRestThreshold * tuning.ballRestThreshold {
            ball.velocity = .zero
        }

        ball.velocity = ball.velocity.limited(to: tuning.ballMaxSpeed)
        ball.position += ball.velocity * dt
        return previous
    }
}
