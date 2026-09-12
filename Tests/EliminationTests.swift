import XCTest
@testable import Svinjara

final class EliminationTests: XCTestCase {

    private let tuning = Tuning.default

    // MARK: Conceding and the reset

    func testTheResetPutsEverythingBackWhereverItWasBefore() {
        guard let played = ScriptedMatch.playToCompletion() else {
            return XCTFail("scripted match never finished")
        }
        // Rebuild a fresh engine and compare a post-goal reset against a kickoff.
        var engine = MatchFixture.engine()
        var strikers = (0..<5).map { TestStriker(index: $0) }
        let kickoff = engine.state

        var resumed = false
        for _ in 0..<400_000 {
            let inputs = (0..<5).map { strikers[$0].input(state: engine.state, tuning: tuning) }
            if engine.step(inputs: inputs).contains(.resumed) { resumed = true; break }
        }
        XCTAssertTrue(resumed, "no goal was ever scored")

        XCTAssertEqual(engine.state.ball.position, kickoff.ball.position)
        XCTAssertEqual(engine.state.ball.velocity, .zero)
        XCTAssertNil(engine.state.ball.lastTouchedBy)
        for player in engine.state.players where player.isAlive {
            XCTAssertEqual(player.body, kickoff.players[player.index].body)
            XCTAssertEqual(player.charge, 0)
            XCTAssertFalse(player.isDashing)
            XCTAssertFalse(player.isStaggered)
            XCTAssertEqual(player.dashCooldown, 0)
        }
        XCTAssertTrue(played.engine.state.isOver)
    }

    func testPlayIsFrozenWhileCelebrating() {
        var engine = MatchFixture.engine()
        var strikers = (0..<5).map { TestStriker(index: $0) }

        for _ in 0..<400_000 {
            let inputs = (0..<5).map { strikers[$0].input(state: engine.state, tuning: tuning) }
            let events = engine.step(inputs: inputs)
            if events.contains(where: { if case .conceded = $0 { return true }; return false }) {
                break
            }
        }
        guard case .celebrating = engine.state.phase else {
            return XCTFail("expected a celebration, got \(engine.state.phase)")
        }

        // Nothing moves, whatever anyone asks for.
        let before = engine.state
        let shoving = [PlayerInput](repeating: PlayerInput(move: Vec2(x: 1, y: 0),
                                                           dashRequested: true), count: 5)
        engine.step(inputs: shoving)
        XCTAssertEqual(engine.state.players.map(\.body), before.players.map(\.body))
        XCTAssertEqual(engine.state.ball, before.ball)
        XCTAssertEqual(engine.state.elapsed, before.elapsed, "celebration is not play time")
    }

    // MARK: Elimination

    func testTheSixthConcedeEliminatesAndSealsTheGoal() {
        guard let (engine, events) = ScriptedMatch.playToCompletion() else {
            return XCTFail("scripted match never finished")
        }

        let eliminations = events.compactMap { event -> (Int, Int)? in
            if case .eliminated(let player, let place) = event { return (player, place) }
            return nil
        }
        XCTAssertEqual(eliminations.count, 4, "four go out, one survives")

        for (player, place) in eliminations {
            XCTAssertGreaterThanOrEqual(engine.state.players[player].conceded,
                                        tuning.concedesToElimination)
            XCTAssertFalse(engine.state.players[player].isAlive)
            XCTAssertFalse(engine.state.arena.isOpen[player], "their goal must be bricked up")
            XCTAssertTrue((2...5).contains(place))
        }
        XCTAssertEqual(eliminations.map(\.1), [5, 4, 3, 2], "places awarded in order")
    }

    func testNobodyEverExceedsSixConceded() {
        guard let (engine, _) = ScriptedMatch.playToCompletion() else {
            return XCTFail("scripted match never finished")
        }
        for player in engine.state.players {
            XCTAssertLessThanOrEqual(player.conceded, tuning.concedesToElimination)
        }
    }

    func testSealingLeavesTheArenaAndTheOtherGoalsAlone() {
        let fresh = ArenaGeometry(tuning: tuning)
        guard let (engine, _) = ScriptedMatch.playToCompletion() else {
            return XCTFail("scripted match never finished")
        }
        let arena = engine.state.arena

        XCTAssertEqual(arena.radius, fresh.radius, "the pitch never changes size")
        XCTAssertEqual(arena.bearings, fresh.bearings, "goals never move")
        XCTAssertEqual(arena.mouthHalfAngle, fresh.mouthHalfAngle)
        XCTAssertEqual(arena.isOpen.filter { $0 }.count, 1, "only the winner's goal is left")
    }

    /// Once a goal is bricked up, a shot at it must rebound rather than register.
    func testAShotAtAnEliminatedPlayersGoalRebounds() {
        var arena = ArenaGeometry(tuning: tuning)
        arena.seal(4)
        let bearing = arena.bearings[4]
        var ball = BallState(position: Vec2(angle: bearing, length: 5),
                             velocity: Vec2(angle: bearing, length: tuning.kickMaxSpeed))

        var outcomes: [BoundaryOutcome] = []
        for _ in 0..<300 {
            outcomes.append(GoalDetector.advance(ball: &ball, arena: arena,
                                                 dt: tuning.fixedStep, tuning: tuning))
        }
        XCTAssertFalse(outcomes.contains { if case .scored = $0 { return true }; return false })
        XCTAssertTrue(outcomes.contains(.bounced))
    }

    // MARK: Winning

    func testAMatchEndsWithExactlyOneWinnerAndFullStandings() {
        guard let (engine, events) = ScriptedMatch.playToCompletion() else {
            return XCTFail("scripted match never finished")
        }

        guard case .finished(let winner) = engine.state.phase else {
            return XCTFail("expected a finished match")
        }
        XCTAssertEqual(engine.state.aliveCount, 1)
        XCTAssertTrue(engine.state.players[winner].isAlive)
        XCTAssertLessThan(engine.state.players[winner].conceded, tuning.concedesToElimination)
        XCTAssertEqual(events.last, .finished(winner: winner))

        let standings = engine.state.standings
        XCTAssertEqual(standings.count, 5)
        XCTAssertEqual(Set(standings).count, 5, "everyone is placed exactly once")
        XCTAssertEqual(standings.first, winner)
        XCTAssertEqual(standings.last, engine.state.eliminationOrder.first, "first out finishes last")
    }

    func testAFinishedMatchIgnoresFurtherInput() {
        guard let (engineAtEnd, _) = ScriptedMatch.playToCompletion() else {
            return XCTFail("scripted match never finished")
        }
        var engine = engineAtEnd
        let frozen = engine.state

        let events = engine.step(inputs: [PlayerInput](repeating: PlayerInput(move: Vec2(x: 1, y: 0)),
                                                        count: 5))
        XCTAssertTrue(events.isEmpty)
        XCTAssertEqual(engine.state, frozen)
    }

    func testMatchLengthIsPlausible() {
        guard let (engine, events) = ScriptedMatch.playToCompletion() else {
            return XCTFail("scripted match never finished")
        }
        let goals = events.filter { if case .conceded = $0 { return true }; return false }.count
        // Four players out at six each, plus whatever the winner let in.
        XCTAssertGreaterThanOrEqual(goals, 24)
        XCTAssertLessThanOrEqual(goals, 24 + tuning.concedesToElimination - 1)
        XCTAssertGreaterThan(engine.state.elapsed, 10, "a match is not over in a blink")
    }
}
