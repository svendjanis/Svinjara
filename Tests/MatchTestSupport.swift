import XCTest
@testable import Svinjara

/// Shared helpers for the rules tests.
enum MatchFixture {

    static var nations: [Nation] {
        Array(NationCatalog.all.prefix(5))
    }

    static func engine(tuning: Tuning = .default) -> MatchEngine {
        MatchEngine(nations: nations, tuning: tuning)
    }

    /// Steps with everyone standing still.
    @discardableResult
    static func idle(_ engine: inout MatchEngine, steps: Int) -> [MatchEvent] {
        var events: [MatchEvent] = []
        let idle = [PlayerInput](repeating: .idle, count: 5)
        for _ in 0..<steps { events += engine.step(inputs: idle) }
        return events
    }

    static func steps(forSeconds seconds: Double, tuning: Tuning = .default) -> Int {
        Int((seconds / tuning.fixedStep).rounded())
    }
}

/// A crude "get behind it and blast it" controller, used to drive a whole match through legal
/// play without waiting for the real AI. It speaks the same `PlayerInput` a human's thumbs do,
/// so a match it drives is a real match.
///
/// It approaches the ball from the side away from its target goal, so that facing the goal
/// also means facing the ball. Turning to aim from wherever you happen to be stood just walks
/// you away from the ball, and the match never gets anywhere.
struct TestStriker {
    let index: Int
    private var holding = false

    init(index: Int) { self.index = index }

    mutating func input(state: MatchState, tuning: Tuning) -> PlayerInput {
        let me = state.players[index]
        guard me.isAlive, state.phase.isPlaying else {
            holding = false
            return .idle
        }

        let target = bestRivalGoal(state: state)
        let toGoal = (state.arena.mouthCentre(of: target) - state.ball.position).normalized
        let behindBall = state.ball.position - toGoal * (tuning.playerRadius + tuning.ballRadius)

        if me.body.position.distance(to: behindBall) > 0.35 {
            holding = true
            return PlayerInput(move: (behindBall - me.body.position).normalized, kickHeld: true)
        }

        let aimed = Angles.separation(me.body.facing, toGoal.angle) < 0.25
        let ready = aimed && KickResolver.canStrike(body: me.body, ball: state.ball, tuning: tuning)
        let input = PlayerInput(move: toGoal, kickHeld: !ready, kickReleased: ready && holding)
        holding = !ready
        return input
    }

    /// The most exposed rival goal: near the ball, and poorly defended by its owner.
    private func bestRivalGoal(state: MatchState) -> Int {
        state.players.filter { $0.isAlive && $0.index != index }
            .min { exposure($0, state) < exposure($1, state) }?.index
            ?? ((index + 1) % state.players.count)
    }

    private func exposure(_ rival: PlayerState, _ state: MatchState) -> Double {
        let mouth = state.arena.mouthCentre(of: rival.index)
        return state.ball.position.distance(to: mouth) - rival.body.position.distance(to: mouth)
    }
}

/// Runs a full match under five strikers and returns the result, or nil if it never ended.
enum ScriptedMatch {

    /// A typical scripted match finishes in about 22 000 steps; the cap is generous enough to
    /// absorb a tuning change and tight enough to fail fast rather than hang the suite.
    static func playToCompletion(tuning: Tuning = .default,
                                 stepCap: Int = 400_000) -> (engine: MatchEngine, events: [MatchEvent])? {
        var engine = MatchFixture.engine(tuning: tuning)
        var strikers = (0..<5).map { TestStriker(index: $0) }
        var events: [MatchEvent] = []

        for _ in 0..<stepCap {
            let inputs = (0..<5).map { strikers[$0].input(state: engine.state, tuning: tuning) }
            events += engine.step(inputs: inputs)
            if engine.state.isOver { return (engine, events) }
        }
        return nil
    }
}
