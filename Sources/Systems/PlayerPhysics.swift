import Foundation

/// A player's physical state. Everything else about them — their nation, their tally, whether
/// they are still alive — lives in `MatchState`; this is only what moves.
struct PlayerBody: Equatable {
    var position: Vec2 = .zero
    var velocity: Vec2 = .zero
    /// Bearing the figure is pointing, which is also the direction a kick will go.
    var facing: Double = 0
}

enum PlayerPhysics {

    /// Advances a player one fixed slice.
    ///
    /// - Parameters:
    ///   - move: desired heading, magnitude `0...1`. A partly-pushed stick means a lower top
    ///     speed, not a lower acceleration, which is what makes a joystick feel precise.
    ///   - dash: when set, movement is overridden entirely for the duration of a lunge.
    ///   - control: steering authority, reduced while staggered.
    static func integrate(_ body: inout PlayerBody,
                          move: Vec2,
                          dash: Vec2?,
                          control: Double,
                          dt: Double,
                          tuning: Tuning) {
        if let dash {
            // A dash is a committed lunge: it ignores the stick, which is what makes
            // mistiming one actually cost you.
            body.velocity = dash.normalized * tuning.dashSpeed
            body.facing = dash.angle
            body.position += body.velocity * dt
            return
        }

        let steer = move.limited(to: 1) * max(0, control)
        let effort = steer.length

        if effort > 1e-6 {
            body.velocity += steer.normalized * (tuning.playerAcceleration * dt)
            body.velocity = body.velocity.limited(to: tuning.playerTopSpeed * effort)
            body.facing = Angles.step(from: body.facing,
                                      to: steer.angle,
                                      maxStep: tuning.playerTurnRate * dt)
        } else {
            body.velocity *= exp(-tuning.playerFriction * dt)
            if body.velocity.lengthSquared < 1e-4 {
                body.velocity = .zero
            } else {
                // Still sliding, so keep facing where the slide is going.
                body.facing = Angles.step(from: body.facing,
                                          to: body.velocity.angle,
                                          maxStep: tuning.playerTurnRate * dt)
            }
        }

        body.position += body.velocity * dt
    }
}
