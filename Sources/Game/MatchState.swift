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

    /// Final standings, best first. The winner, then the eliminated in reverse order of
    /// leaving — the last one knocked out was the runner-up.
    var standings: [Int] {
        let survivors = players.filter(\.isAlive).map(\.index)
        return survivors + eliminationOrder.reversed()
    }
}
