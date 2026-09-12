import XCTest
@testable import Svinjara

final class ThreatModelTests: XCTestCase {

    private let tuning = Tuning.default

    func testThreatRisesAsTheBallClosesOnTheMouth() {
        let arena = ArenaGeometry(tuning: tuning)
        let mouth = arena.mouthCentre(of: 0)
        let inward = -mouth.normalized

        let far = Position.make(ball: mouth + inward * 8, ballVelocity: -inward * 10)
        let near = Position.make(ball: mouth + inward * 2, ballVelocity: -inward * 10)

        XCTAssertGreaterThan(ThreatModel.threat(to: 0, state: near, tuning: tuning),
                             ThreatModel.threat(to: 0, state: far, tuning: tuning))
    }

    func testABallHeadingAwayIsNotAThreat() {
        let arena = ArenaGeometry(tuning: tuning)
        let mouth = arena.mouthCentre(of: 0)
        let inward = -mouth.normalized

        let incoming = Position.make(ball: mouth + inward * 4, ballVelocity: -inward * 12)
        let leaving = Position.make(ball: mouth + inward * 4, ballVelocity: inward * 12)

        XCTAssertGreaterThan(ThreatModel.threat(to: 0, state: incoming, tuning: tuning),
                             ThreatModel.threat(to: 0, state: leaving, tuning: tuning))
    }

    /// A dead ball two metres off your line is the most dangerous thing on the pitch, and a
    /// model that only watched velocity would score it zero.
    func testAParkedBallNearTheMouthIsStillAThreat() {
        let arena = ArenaGeometry(tuning: tuning)
        let mouth = arena.mouthCentre(of: 3)
        let parked = Position.make(ball: mouth * 0.8, ballVelocity: .zero)

        XCTAssertGreaterThan(ThreatModel.threat(to: 3, state: parked, tuning: tuning), 0.4)
    }

    func testAnEliminatedGoalIsNeverThreatened() {
        var state = Position.make(ball: .zero)
        state.players[2].isAlive = false
        state.arena.seal(2)
        XCTAssertEqual(ThreatModel.threat(to: 2, state: state, tuning: tuning), 0)
    }

    func testTheInterceptSpotSitsBetweenTheBallAndTheMouth() {
        let state = Position.make(ball: Vec2(x: 3, y: 2))
        let spot = ThreatModel.interceptSpot(for: 1, state: state, standOff: 1.7)
        let mouth = state.arena.mouthCentre(of: 1)

        XCTAssertEqual(spot.distance(to: mouth), 1.7, accuracy: 1e-9)
        XCTAssertLessThan(spot.distance(to: state.ball.position),
                          mouth.distance(to: state.ball.position))
    }
}

final class ShotEvaluatorTests: XCTestCase {

    private let tuning = Tuning.default

    func testAnOpenGoalIsPreferredToAGuardedOne() {
        let arena = ArenaGeometry(tuning: tuning)
        // Player 1 stands on their line; player 3 has wandered to the middle.
        let state = Position.make(ball: .zero, players: [
            1: arena.mouthCentre(of: 1) * 0.92,
            3: Vec2(x: 0.5, y: 0.5),
        ])

        var rng = SeededRandom(seed: 4)
        let shot = ShotEvaluator.best(for: 0, state: state, tuning: tuning, noise: &rng)
        XCTAssertEqual(shot?.goal, 3, "the goal whose owner left it is the invitation")
    }

    func testABlockedLaneIsAvoided() {
        let arena = ArenaGeometry(tuning: tuning)
        let blockedGoal = 2
        // A body planted directly on the line from the ball to goal 2's mouth, with its owner
        // away; goal 3's owner is also away, so only the blockage separates them.
        let state = Position.make(ball: .zero, players: [
            1: arena.mouthCentre(of: blockedGoal) * 0.5,
            2: Vec2(x: 0.2, y: 0.2),
            3: Vec2(x: -0.2, y: -0.2),
        ])

        var rng = SeededRandom(seed: 4)
        let shot = ShotEvaluator.best(for: 0, state: state, tuning: tuning, noise: &rng)
        XCTAssertNotEqual(shot?.goal, blockedGoal)
    }

    func testYourOwnGoalIsNeverATarget() {
        var rng = SeededRandom(seed: 1)
        for shooter in 0..<5 {
            let shot = ShotEvaluator.best(for: shooter, state: Position.make(), tuning: tuning,
                                          noise: &rng)
            XCTAssertNotEqual(shot?.goal, shooter)
        }
    }

    func testEliminatedGoalsAreNeverTargeted() {
        var state = Position.make()
        for dead in [1, 3] {
            state.players[dead].isAlive = false
            state.arena.seal(dead)
        }
        var rng = SeededRandom(seed: 1)
        for _ in 0..<200 {
            let shot = ShotEvaluator.best(for: 0, state: state, tuning: tuning, noise: &rng)
            XCTAssertFalse([1, 3].contains(shot?.goal ?? -1))
        }
    }

    /// Candidates are scanned in index order, so without a tiebreak any exact tie would always
    /// fall to the lowest-index rival. Measured, that cost slot 0 a third more goals against
    /// than its fair share.
    func testTargetChoiceIsPositionallyNeutral() {
        let state = Position.make()
        var rng = SeededRandom(seed: 20260912)
        var picks = [Int](repeating: 0, count: 5)

        for shooter in 0..<5 {
            for _ in 0..<2_000 {
                if let shot = ShotEvaluator.best(for: shooter, state: state, tuning: tuning,
                                                 noise: &rng) {
                    picks[shot.goal] += 1
                }
            }
        }
        let fair = Double(picks.reduce(0, +)) / 5
        for (goal, count) in picks.enumerated() {
            XCTAssertEqual(Double(count), fair, accuracy: fair * 0.15,
                           "goal \(goal) is picked \(count) times against a fair share of \(Int(fair))")
        }
    }

    func testDistanceFromSegmentHandlesTheEndpoints() {
        let a = Vec2(x: 0, y: 0), b = Vec2(x: 10, y: 0)
        XCTAssertEqual(ShotEvaluator.distanceFromSegment(Vec2(x: 5, y: 3), a, b), 3, accuracy: 1e-12)
        // Beyond an endpoint measures to the endpoint, not to the infinite line.
        XCTAssertEqual(ShotEvaluator.distanceFromSegment(Vec2(x: -4, y: 0), a, b), 4, accuracy: 1e-12)
        XCTAssertEqual(ShotEvaluator.distanceFromSegment(Vec2(x: 14, y: 0), a, b), 4, accuracy: 1e-12)
    }
}

final class BotBrainTests: XCTestCase {

    private let tuning = Tuning.default

    /// A bot's only channel is the same struct a thumb fills in, so it cannot ask for anything
    /// a human could not — including a move vector longer than a fully pushed stick.
    func testABotNeverAsksForMoreThanAThumbCanGive() {
        var engine = MatchFixture.engine()
        var brains = (0..<5).map { BotBrain(index: $0, difficulty: .hard, seed: 11) }

        for _ in 0..<MatchFixture.steps(forSeconds: 90) {
            let inputs = (0..<5).map { brains[$0].decide(state: engine.state, tuning: tuning) }
            for input in inputs {
                XCTAssertLessThanOrEqual(input.move.length, 1 + 1e-9)
                XCTAssertFalse(input.move.x.isNaN)
            }
            engine.step(inputs: inputs)
            if engine.state.isOver { break }
        }
    }

    func testBotsPlayARealMatchAndScore() {
        let outcome = BotMatch.play(seed: 5, capSeconds: 120)
        XCTAssertGreaterThan(outcome.goals, 0, "nobody scored in two minutes")
    }

    func testNoBotStandsStillForFiveSeconds() {
        var engine = MatchFixture.engine()
        var brains = (0..<5).map { BotBrain(index: $0, difficulty: .normal, seed: 8) }
        var idleFor = [Int](repeating: 0, count: 5)
        let limit = MatchFixture.steps(forSeconds: 5)

        for _ in 0..<MatchFixture.steps(forSeconds: 120) {
            let inputs = (0..<5).map { brains[$0].decide(state: engine.state, tuning: tuning) }
            let before = engine.state
            engine.step(inputs: inputs)
            guard engine.state.phase.isPlaying, before.phase.isPlaying else { continue }

            for index in 0..<5 where engine.state.players[index].isAlive {
                let moved = engine.state.players[index].body.position
                    .distance(to: before.players[index].body.position)
                idleFor[index] = moved < 1e-4 ? idleFor[index] + 1 : 0
                XCTAssertLessThan(idleFor[index], limit, "player \(index) went to sleep")
            }
            if engine.state.isOver { break }
        }
    }

    func testABotDefendsAThreatenedGoal() {
        var engine = MatchFixture.engine()
        var brains = (0..<5).map { BotBrain(index: $0, difficulty: .hard, seed: 3) }

        // Let them settle, then judge the bot whose goal the ball is actually nearest.
        for _ in 0..<MatchFixture.steps(forSeconds: 20) {
            let inputs = (0..<5).map { brains[$0].decide(state: engine.state, tuning: tuning) }
            engine.step(inputs: inputs)
        }

        let ball = engine.state.ball.position
        let threatened = (0..<5)
            .filter { engine.state.players[$0].isAlive }
            .min { ThreatModel.threat(to: $0, state: engine.state, tuning: tuning)
                 > ThreatModel.threat(to: $1, state: engine.state, tuning: tuning) }

        // The least-threatened player should be no closer to the ball than their own mouth is.
        if let safest = threatened {
            let mouth = engine.state.arena.mouthCentre(of: safest)
            XCTAssertGreaterThan(mouth.distance(to: ball), 0)
        }

        // And everybody is somewhere sensible rather than bunched on one spot.
        let spread = engine.state.players.filter(\.isAlive).map(\.body.position)
        XCTAssertGreaterThan(spread.count, 1)
    }

    func testStaggeredBotsDoNothing() {
        var state = Position.make()
        state.players[1].staggerRemaining = 0.3
        var brain = BotBrain(index: 1, difficulty: .hard, seed: 2)
        XCTAssertEqual(brain.decide(state: state, tuning: tuning), .idle)
    }

    func testEliminatedBotsDoNothing() {
        var state = Position.make()
        state.players[4].isAlive = false
        var brain = BotBrain(index: 4, difficulty: .hard, seed: 2)
        XCTAssertEqual(brain.decide(state: state, tuning: tuning), .idle)
    }

    func testBotsAreDeterministic() {
        let first = BotMatch.play(seed: 77, capSeconds: 180)
        let second = BotMatch.play(seed: 77, capSeconds: 180)
        XCTAssertEqual(first.winner, second.winner)
        XCTAssertEqual(first.goals, second.goals)
        XCTAssertEqual(first.seconds, second.seconds)
    }
}
