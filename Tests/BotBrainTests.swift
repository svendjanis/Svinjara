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

    /// A bot must not go to sleep *when it has something to do*.
    ///
    /// The condition matters. An earlier version of this test simply forbade standing still
    /// for five seconds, and it started failing the moment players began restarting on their
    /// own line rather than four metres in front of it — because a defender holding station
    /// while the ball is fifteen metres away at the far side of the circle is doing exactly
    /// the right thing. Standing still is only a bug if you are the one who should be moving.
    func testNoBotFallsAsleepWithTheBallOnTopOfIt() {
        var engine = MatchFixture.engine()
        var brains = (0..<5).map { BotBrain(index: $0, difficulty: .normal, seed: 8) }
        var idleFor = [Int](repeating: 0, count: 5)
        let limit = MatchFixture.steps(forSeconds: 3)

        for _ in 0..<MatchFixture.steps(forSeconds: 180) {
            let inputs = (0..<5).map { brains[$0].decide(state: engine.state, tuning: tuning) }
            let before = engine.state
            engine.step(inputs: inputs)
            guard engine.state.phase.isPlaying, before.phase.isPlaying else { continue }

            // Whoever is nearest the ball is the one with something to do.
            let contender = engine.state.players
                .filter(\.isAlive)
                .min { $0.body.position.distance(to: engine.state.ball.position)
                     < $1.body.position.distance(to: engine.state.ball.position) }?.index

            for index in 0..<5 where engine.state.players[index].isAlive {
                let moved = engine.state.players[index].body.position
                    .distance(to: before.players[index].body.position)
                let hasBusiness = index == contender
                    && !engine.state.players[index].isStaggered

                idleFor[index] = (moved < 1e-4 && hasBusiness) ? idleFor[index] + 1 : 0
                XCTAssertLessThan(idleFor[index], limit,
                                  "player \(index) is nearest the ball and has not moved")
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
    /// Every tier holds the stick a little short of the rim, so the person holding the phone
    /// is the fastest thing on the pitch when they want to be. See `BotDifficulty.pace`.
    func testABotNeverRunsAtFullTilt() {
        var engine = MatchFixture.engine()
        var brains = (0..<5).map { BotBrain(index: $0, difficulty: .hard, seed: 12) }
        var sawMovement = false

        for _ in 0..<MatchFixture.steps(forSeconds: 60) {
            let inputs = (0..<5).map { brains[$0].decide(state: engine.state, tuning: tuning) }
            for (index, input) in inputs.enumerated() where input.move.lengthSquared > 1e-9 {
                sawMovement = true
                XCTAssertLessThanOrEqual(input.move.length,
                                         brains[index].difficulty.pace + 1e-9)
            }
            engine.step(inputs: inputs)
            if engine.state.isOver { break }
        }
        XCTAssertTrue(sawMovement, "nobody moved, so nothing was measured")
    }

    /// A bot must not take a shot simply because it is the best one available — the best
    /// available is often dreadful. Standing over the ball on your own line with every rival
    /// at home is exactly that case, and hitting it from there is what a restart used to be.
    func testABotCarriesRatherThanTakingAHopelessShot() {
        let arena = ArenaGeometry(tuning: tuning)
        // The ball on player 0's own goal-kick spot, at their feet, everyone else at home.
        let spot = Vec2(angle: arena.bearings[0], length: arena.radius * tuning.goalKickFraction)
        var state = Position.make(ball: spot, players: [
            0: Vec2(angle: arena.bearings[0],
                    length: arena.radius * tuning.goalKickFraction
                            + tuning.playerRadius + tuning.ballRadius),
        ])
        state.players[0].body.facing = Angles.normalize(arena.bearings[0] + .pi)

        var brain = BotBrain(index: 0, difficulty: .normal, seed: 4)
        var struck = false
        for _ in 0..<MatchFixture.steps(forSeconds: 0.8) {
            if brain.decide(state: state, tuning: tuning).kickReleased { struck = true }
        }
        XCTAssertFalse(struck, "a goal kick is not a shooting opportunity")
    }

    /// Whatever the bot remembers about where the ball was, a restart is not the moment to
    /// act on it: what the buffer holds while a goal is celebrated is the ball crossing a
    /// line, and carrying that over means shooting at a position the ball is nowhere near.
    func testABotDoesNotStillSeeTheBallInTheNetAfterARestart() {
        var engine = MatchFixture.engine()
        var brains = (0..<5).map { BotBrain(index: $0, difficulty: .hard, seed: 6) }
        var resumed = false

        for _ in 0..<MatchFixture.steps(forSeconds: 300) {
            let inputs = (0..<5).map { brains[$0].decide(state: engine.state, tuning: tuning) }
            let events = engine.step(inputs: inputs)
            if events.contains(.resumed) { resumed = true; break }
        }
        XCTAssertTrue(resumed, "no goal was ever scored")

        // The step after the whistle: nobody may be trying to kick a ball they are not near.
        let inputs = (0..<5).map { brains[$0].decide(state: engine.state, tuning: tuning) }
        for (index, input) in inputs.enumerated() where input.kickReleased {
            XCTAssertTrue(KickResolver.canStrike(body: engine.state.players[index].body,
                                                 ball: engine.state.ball, tuning: tuning),
                          "player \(index) swung at a ball that is not there")
        }
    }

    /// Closing the ball down is for the next nearest player, and nobody else. Sending
    /// everybody leaves five goals empty, which is the failure this game started with;
    /// sending nobody means a ball at somebody's feet crosses the whole pitch unopposed,
    /// which is what it did before pressing existed.
    ///
    /// Two at once is allowed and briefly happens: each bot ranks itself using its own
    /// slightly stale view of where the ball is, and holds a decision for a moment after
    /// making it, so two can believe they are second nearest while the ball changes hands.
    /// Three would mean the ranking is not doing its job.
    func testPressingIsForTheNextNearestPlayerAndNobodyElse() {
        var engine = MatchFixture.engine()
        var brains = (0..<5).map { BotBrain(index: $0, difficulty: .normal, seed: 21) }
        var pressSteps = 0
        var steps = 0

        for _ in 0..<MatchFixture.steps(forSeconds: 240) {
            let inputs = (0..<5).map { brains[$0].decide(state: engine.state, tuning: tuning) }
            let pressing = brains.filter { $0.currentMode == .press }.count
            XCTAssertLessThanOrEqual(pressing, 2, "\(pressing) players left their goal at once")
            pressSteps += pressing
            steps += 1
            engine.step(inputs: inputs)
            if engine.state.isOver { break }
        }

        let average = Double(pressSteps) / Double(steps)
        XCTAssertLessThan(average, 1.05, "on average \(average) players are chasing the ball")
        XCTAssertGreaterThan(average, 0.2, "nobody ever closes anybody down")
    }

    /// The case the ranking exists for: at a restart the four players who are not taking it
    /// stand at identical distances from the ball, and a `<=` made every one of them the
    /// second nearest — all four charged, and the kickoff was a five-way sprint leaving five
    /// empty mouths, which is the exact thing the goal kick exists to prevent.
    func testNobodyAbandonsTheirGoalAtARestart() {
        var engine = MatchFixture.engine()
        var brains = (0..<5).map { BotBrain(index: $0, difficulty: .normal, seed: 21) }
        var restarts = 0

        for _ in 0..<MatchFixture.steps(forSeconds: 300) {
            let inputs = (0..<5).map { brains[$0].decide(state: engine.state, tuning: tuning) }
            guard engine.step(inputs: inputs).contains(.resumed) else {
                if engine.state.isOver { break }
                continue
            }
            // The taker is going for it by definition — it is already at their feet. The
            // question is how many of the other four leave their line to join in.
            guard let taker = engine.state.restartTaker else { continue }
            restarts += 1
            _ = (0..<5).map { brains[$0].decide(state: engine.state, tuning: tuning) }

            let chasing = brains.filter {
                $0.index != taker && ($0.currentMode == .press || $0.currentMode == .attack)
            }
            XCTAssertLessThanOrEqual(chasing.count, 1,
                                     "\(chasing.count) players left their own goal at a restart")
            XCTAssertEqual(brains[taker].currentMode, .attack, "the taker has the ball")
            if engine.state.isOver { break }
        }
        XCTAssertGreaterThan(restarts, 5, "not enough restarts to judge")
    }

    /// The taker of a goal kick must actually get to keep it for a moment.
    ///
    /// Giving them the ball was never the hard part — it is at their feet at the whistle and
    /// the nearest rival is eight metres away. But a bot takes its first touch 0.01 s after
    /// the whistle, and a person who has just watched a goal go in has not got their thumb
    /// back on the stick yet. Measured before the bots stood off, the taker had a median of
    /// 1.75 s before a rival could kick it and only a third of restarts survived two seconds,
    /// so what a restart felt like was the ball being put near your goal and taken off you.
    func testTheTakerOfAGoalKickIsLeftAloneForAMoment() {
        var engine = MatchFixture.engine()
        var brains = (0..<5).map { BotBrain(index: $0, difficulty: .hard, seed: 17) }
        var measured = 0

        // Player 0 idles throughout — a person still watching the goal they just let in.
        var watching: (taker: Int, since: Double)?
        for _ in 0..<MatchFixture.steps(forSeconds: 300) {
            var inputs = (0..<5).map { brains[$0].decide(state: engine.state, tuning: tuning) }
            inputs[0] = .idle
            for event in engine.step(inputs: inputs) where event == .resumed {
                watching = engine.state.restartTaker.map { ($0, engine.state.elapsed) }
            }

            guard let watch = watching, engine.state.phase.isPlaying else { continue }
            let held = engine.state.elapsed - watch.since
            let contested = engine.state.players.contains {
                $0.isAlive && $0.index != watch.taker
                    && KickResolver.canStrike(body: $0.body, ball: engine.state.ball,
                                              tuning: tuning)
            }
            if contested {
                XCTAssertGreaterThan(held, 1.5,
                                     "a rival reached the goal kick after only \(held) s")
                measured += 1
                watching = nil
            } else if held > 3 {
                measured += 1
                watching = nil
            }
            if engine.state.isOver { break }
        }
        XCTAssertGreaterThan(measured, 8, "not enough restarts to judge")
    }

    /// And the stand-off is for somebody else's restart only — the taker goes for their own.
    func testTheTakerIsNotStoodOffFromTheirOwnGoalKick() {
        var engine = MatchFixture.engine()
        var brains = (0..<5).map { BotBrain(index: $0, difficulty: .normal, seed: 17) }
        var checked = 0

        for _ in 0..<MatchFixture.steps(forSeconds: 300) {
            let inputs = (0..<5).map { brains[$0].decide(state: engine.state, tuning: tuning) }
            guard engine.step(inputs: inputs).contains(.resumed) else {
                if engine.state.isOver { break }
                continue
            }
            guard let taker = engine.state.restartTaker else { continue }
            _ = (0..<5).map { brains[$0].decide(state: engine.state, tuning: tuning) }
            XCTAssertEqual(brains[taker].currentMode, .attack,
                           "the taker stood off from their own goal kick")
            checked += 1
            if engine.state.isOver { break }
        }
        XCTAssertGreaterThan(checked, 5, "not enough restarts to judge")
    }

}
