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

/// Builds an arbitrary match position, for testing the pieces of the AI that are pure
/// functions of a situation.
enum Position {

    static func make(tuning: Tuning = .default,
                     ball: Vec2 = .zero,
                     ballVelocity: Vec2 = .zero,
                     players: [Int: Vec2] = [:]) -> MatchState {
        let arena = ArenaGeometry(tuning: tuning)
        let states = MatchFixture.nations.enumerated().map { index, nation in
            PlayerState(index: index,
                        nation: nation,
                        appearance: AppearanceFactory.make(seed: UInt64(index)),
                        body: PlayerBody(
                            position: players[index]
                                ?? arena.homeSpot(of: index, fraction: tuning.homeSpotFraction),
                            velocity: .zero,
                            facing: 0))
        }
        var state = MatchState(arena: arena, players: states)
        state.ball = BallState(position: ball, velocity: ballVelocity)
        return state
    }
}

/// Plays a whole match under bots and reports what happened.
enum BotMatch {

    struct Outcome {
        let winner: Int?
        let seconds: Double
        let goals: Int
        let events: [MatchEvent]
        /// The final state, so the rules tests can inspect what the match left behind.
        let state: MatchState

        var finished: Bool { winner != nil }
    }

    static func play(seed: UInt64,
                     difficulties: [BotDifficulty] = [BotDifficulty](repeating: .normal, count: 5),
                     tuning: Tuning = .default,
                     capSeconds: Double = 900,
                     collectEvents: Bool = false) -> Outcome {
        var engine = MatchFixture.engine(tuning: tuning)
        var brains = (0..<5).map { BotBrain(index: $0, difficulty: difficulties[$0], seed: seed) }
        var goals = 0
        var events: [MatchEvent] = []

        for _ in 0..<Int(capSeconds / tuning.fixedStep) {
            let inputs = (0..<5).map { brains[$0].decide(state: engine.state, tuning: tuning) }
            let stepEvents = engine.step(inputs: inputs)
            for event in stepEvents where event.isConcede { goals += 1 }
            if collectEvents { events += stepEvents }
            if engine.state.isOver { break }
        }
        return Outcome(winner: engine.state.winner, seconds: engine.state.elapsed,
                       goals: goals, events: events, state: engine.state)
    }

    /// A finished match with its full event list, or a test failure if it never ended.
    static func completed(seed: UInt64 = 21,
                          tuning: Tuning = .default,
                          file: StaticString = #filePath,
                          line: UInt = #line) -> Outcome? {
        let outcome = play(seed: seed, tuning: tuning, capSeconds: 900, collectEvents: true)
        guard outcome.finished else {
            XCTFail("bot match never reached a winner", file: file, line: line)
            return nil
        }
        return outcome
    }
}

extension MatchEvent {
    var isConcede: Bool {
        if case .conceded = self { return true }
        return false
    }
}
