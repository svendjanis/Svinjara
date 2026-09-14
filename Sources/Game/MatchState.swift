import Foundation

enum MatchPhase: Equatable {
    case playing
    /// Frozen after a goal. The concede has already been applied — only the pause is pending.
    case celebrating(remaining: Double)
    case finished(winner: Int)

    var isPlaying: Bool { self == .playing }
}

/// One player: who they are, where they are, and how close they are to walking home.
struct PlayerState: Equatable {
    /// Also the index of the goal they defend. Player 0 is the human and owns the goal at the
    /// bottom of the screen.
    let index: Int
    let nation: Nation
    let appearance: Appearance

    var body = PlayerBody()
    var conceded = 0
    var isAlive = true

    /// Seconds the kick button has been held. Zero when not charging.
    var charge: Double = 0
    var isCharging = false

    var dashRemaining: Double = 0
    var dashCooldown: Double = 0
    var dashDirection: Vec2 = .zero
    var staggerRemaining: Double = 0

    var isDashing: Bool { dashRemaining > 0 }
    var isStaggered: Bool { staggerRemaining > 0 }

    /// Charge as a fraction of a full one, `0...1`.
    func chargeFraction(tuning: Tuning) -> Double {
        min(1, max(0, charge / tuning.kickChargeTime))
    }
}

/// The whole match. `MatchEngine` is the only thing permitted to mutate it.
struct MatchState: Equatable {
    var arena: ArenaGeometry
    var players: [PlayerState]
    var ball = BallState()
    var phase: MatchPhase = .playing

    /// Seconds of play, excluding celebration pauses.
    var elapsed: Double = 0

    /// Players in the order they were knocked out. The first entry finished last.
    var eliminationOrder: [Int] = []

    /// Where the ball was when the stagnation clock last restarted, and how long it has been
    /// loitering within reach of it.
    var stagnationAnchor: Vec2 = .zero
    var stagnationTimer: Double = 0

    /// Who restarts play: the player the goal was scored against. They take a goal kick — the
    /// ball is placed in front of their own mouth and they stand behind it. Everybody else
    /// lines up on their own goal.
    ///
    /// A restart used to put all five players the same distance from a ball on the centre
    /// spot, which is a five-way sprint with a free shot at four unguarded mouths as the
    /// prize. It was not a rare accident either — measured over 24 bot matches, 26% of every
    /// goal in the game arrived in the same quarter-second of every restart, 2.25–2.50 s
    /// after the whistle. The same race, won by the same run, ending the same way.
    ///
    /// Restarting from the conceder's own goal answers it at the geometry rather than at the
    /// AI: there is no race, because the ball is already at somebody's feet, and there is no
    /// quick goal available, because from there the nearest rival mouth is ten metres away
    /// with all five players stood on their own lines. It is also the fair direction to
    /// resolve it — the restart is small compensation for the goal just conceded.
    ///
    /// `nil` for the opening kickoff, which nobody has earned and which is played from the
    /// centre spot, and for a restart whose taker was eliminated by the goal that caused it.
    var restartTaker: Int?

    /// How many times play has been restarted. Only ever read as the seed for the line-up
    /// nudge in `MatchEngine.resetForKickoff` — see there for why a restart must not look
    /// exactly like the last one.
    var restartCount: Int = 0

    var alivePlayers: [PlayerState] { players.filter(\.isAlive) }
    var aliveCount: Int { players.reduce(0) { $0 + ($1.isAlive ? 1 : 0) } }

    var isOver: Bool {
        if case .finished = phase { return true }
        return false
    }

    var winner: Int? {
        if case .finished(let winner) = phase { return winner }
        return nil
    }

    /// Standings, best first: whoever is still in, then the eliminated in reverse order of
    /// leaving — the last one knocked out was the runner-up.
    ///
    /// Survivors are ranked by how few they have let in rather than by index, which matters
    /// when the table is read before the match has run its course: the human's match ends the
    /// moment *they* are out, and at that point there can still be several players standing.
    var standings: [Int] {
        let survivors = players
            .filter(\.isAlive)
            .sorted { ($0.conceded, $0.index) < ($1.conceded, $1.index) }
            .map(\.index)
        return survivors + eliminationOrder.reversed()
    }
}
