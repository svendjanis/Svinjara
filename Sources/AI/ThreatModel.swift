import Foundation

/// How much trouble a goal is in. Drives the single biggest decision a bot makes each moment:
/// go and get the ball, or go home.
enum ThreatModel {

    /// Danger to `goal`, roughly `0` (safe) to `1` (about to be scored against).
    ///
    /// Two ways to be in trouble, and the worse one wins: the ball is *arriving* — heading at
    /// the mouth and due soon — or the ball is simply *parked* near the mouth, where anyone
    /// who reaches it first scores. A model that only watched velocity would ignore a dead
    /// ball sitting two metres from the line, which is the most dangerous thing on the pitch.
    static func threat(to goal: Int, state: MatchState, tuning: Tuning) -> Double {
        guard state.players[goal].isAlive else { return 0 }

        let mouth = state.arena.mouthCentre(of: goal)
        let toMouth = mouth - state.ball.position
        let distance = toMouth.length
        guard distance > 1e-6 else { return 1 }

        let closing = state.ball.velocity.dot(toMouth / distance)
        let arriving: Double
        if closing > 0.5 {
            let eta = distance / closing
            arriving = 1 / (eta + 0.45)
        } else {
            arriving = 0
        }

        let parked = max(0, 1 - distance / (state.arena.radius * 0.9)) * 0.75

        return min(1, max(arriving, parked))
    }

    /// Where the ball will cross this goal's line if nothing touches it, or nil if it is not
    /// on its way. Used to pick the spot worth standing on rather than chasing the ball itself.
    static func interceptSpot(for goal: Int, state: MatchState, standOff: Double) -> Vec2 {
        let mouth = state.arena.mouthCentre(of: goal)
        let fromBall = (mouth - state.ball.position)
        guard fromBall.lengthSquared > 1e-9 else { return mouth * 0.85 }
        return mouth - fromBall.normalized * standOff
    }
}
