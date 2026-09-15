import XCTest
@testable import Svinjara

final class MatchEngineTests: XCTestCase {

    private let tuning = Tuning.default

    // MARK: Setup

    /// Near their home spot rather than exactly on it: every line-up is nudged, so that no two
    /// restarts in a match present the same picture. See `MatchEngine.resetForKickoff`.
    func testEveryoneStartsInFrontOfTheirOwnGoalFacingTheMiddle() {
        let engine = MatchFixture.engine()
        for player in engine.state.players {
            let home = engine.state.arena.homeSpot(of: player.index,
                                                   fraction: tuning.homeSpotFraction)
            let drift = player.body.position.distance(to: home)
            XCTAssertLessThan(drift, tuning.pitchRadius * tuning.kickoffSpread
                                     + engine.state.arena.mouthHalfAngle * tuning.pitchRadius,
                              "player \(player.index) starts nowhere near their own goal")
            XCTAssertEqual(player.conceded, 0)
            XCTAssertTrue(player.isAlive)

            // Whatever the nudge did, the mouth they are stood in front of is still their own.
            XCTAssertEqual(engine.state.arena.openGoal(atBearing: player.body.position.angle),
                           player.index)

            let towardCentre = (Vec2.zero - player.body.position).angle
            XCTAssertEqual(Angles.separation(player.body.facing, towardCentre), 0, accuracy: 1e-9)
        }
        XCTAssertEqual(engine.state.ball.position, .zero, "the opening kickoff is from the spot")
        XCTAssertEqual(engine.state.phase, .playing)
    }

    func testEveryPlayerGetsADifferentFace() {
        let engine = MatchFixture.engine()
        let faces = engine.state.players.map(\.appearance)
        XCTAssertEqual(Set(faces.map { "\($0.skin)-\($0.hair)-\($0.style)" }).count, 5)
    }

    // MARK: Charge and kick

    func testHoldingBuildsChargeAndReleasingStrikes() {
        var engine = MatchFixture.engine()
        // Walk player 0 onto the ball first.
        var inputs = [PlayerInput](repeating: .idle, count: 5)
        inputs[0] = PlayerInput(move: (Vec2.zero - engine.state.players[0].body.position).normalized,
                                kickHeld: true)

        // Walk until the ball is actually strikeable — the charge fills in 0.55 s but the
        // home spot is 6 m away, so stopping at a full charge would release out of range.
        var events: [MatchEvent] = []
        var reached = false
        for _ in 0..<MatchFixture.steps(forSeconds: 6) {
            events += engine.step(inputs: inputs)
            let player = engine.state.players[0]
            if KickResolver.canStrike(body: player.body, ball: engine.state.ball, tuning: tuning),
               player.charge >= tuning.kickChargeTime {
                reached = true
                break
            }
            inputs[0].move = (engine.state.ball.position - engine.state.players[0].body.position).normalized
        }
        XCTAssertTrue(reached, "never got to the ball")
        XCTAssertEqual(engine.state.players[0].charge, tuning.kickChargeTime, accuracy: 1e-9)
        XCTAssertTrue(engine.state.players[0].isCharging)

        inputs[0].kickHeld = false
        inputs[0].kickReleased = true
        events = engine.step(inputs: inputs)

        XCTAssertTrue(events.contains { if case .kicked(0, _) = $0 { return true }; return false },
                      "expected a kick, got \(events)")
        XCTAssertEqual(engine.state.players[0].charge, 0)
    }

    func testChargeIsCappedWhileHolding() {
        var engine = MatchFixture.engine()
        var inputs = [PlayerInput](repeating: .idle, count: 5)
        inputs[0] = PlayerInput(kickHeld: true)
        for _ in 0..<MatchFixture.steps(forSeconds: 5) { engine.step(inputs: inputs) }
        XCTAssertEqual(engine.state.players[0].charge, tuning.kickChargeTime, accuracy: 1e-12)
    }

    // MARK: Dash

    func testDashLastsItsDurationThenGoesOnCooldown() {
        var engine = MatchFixture.engine()
        var inputs = [PlayerInput](repeating: .idle, count: 5)
        inputs[0] = PlayerInput(move: Vec2(x: 1, y: 0), dashRequested: true)

        let events = engine.step(inputs: inputs)
        XCTAssertTrue(events.contains(.dashed(player: 0)))
        XCTAssertTrue(engine.state.players[0].isDashing)

        // One step's slack: the lunge is armed on the step it is asked for and only starts
        // counting down on the next one.
        inputs[0].dashRequested = false
        for _ in 0..<MatchFixture.steps(forSeconds: tuning.dashDuration + tuning.fixedStep) {
            engine.step(inputs: inputs)
        }
        XCTAssertFalse(engine.state.players[0].isDashing)
        XCTAssertEqual(engine.state.players[0].dashCooldown, tuning.dashCooldown, accuracy: 0.02)
    }

    func testDashIsRefusedWhileOnCooldown() {
        var engine = MatchFixture.engine()
        var inputs = [PlayerInput](repeating: .idle, count: 5)
        inputs[0] = PlayerInput(move: Vec2(x: 1, y: 0), dashRequested: true)
        engine.step(inputs: inputs)

        // Wait out the lunge, then ask again immediately — must be refused.
        inputs[0].dashRequested = false
        for _ in 0..<MatchFixture.steps(forSeconds: tuning.dashDuration + 0.01) {
            engine.step(inputs: inputs)
        }
        inputs[0].dashRequested = true
        let events = engine.step(inputs: inputs)
        XCTAssertFalse(events.contains(.dashed(player: 0)))

        // And is allowed again once the cooldown expires.
        inputs[0].dashRequested = false
        for _ in 0..<MatchFixture.steps(forSeconds: tuning.dashCooldown + 0.02) {
            engine.step(inputs: inputs)
        }
        inputs[0].dashRequested = true
        XCTAssertTrue(engine.step(inputs: inputs).contains(.dashed(player: 0)))
    }

    func testDashingIntoSomeoneShovesAndStaggersThem() {
        var engine = MatchFixture.engine()

        // Drive 0 and 1 together until they touch, then have 0 lunge.
        var shoved: MatchEvent?
        for stepIndex in 0..<MatchFixture.steps(forSeconds: 6) {
            var inputs = [PlayerInput](repeating: .idle, count: 5)
            let toward1 = (engine.state.players[1].body.position - engine.state.players[0].body.position)
            inputs[0] = PlayerInput(move: toward1.normalized,
                                    dashRequested: toward1.length < 1.4 && stepIndex > 10)
            let events = engine.step(inputs: inputs)
            if let event = events.first(where: { if case .shoved = $0 { return true }; return false }) {
                shoved = event
                break
            }
        }

        XCTAssertEqual(shoved, .shoved(by: 0, victim: 1))
        XCTAssertTrue(engine.state.players[1].isStaggered)
    }

    func testStaggerExpiresAfterItsDuration() {
        var engine = MatchFixture.engine()
        for _ in 0..<MatchFixture.steps(forSeconds: 6) {
            var inputs = [PlayerInput](repeating: .idle, count: 5)
            let toward1 = (engine.state.players[1].body.position - engine.state.players[0].body.position)
            inputs[0] = PlayerInput(move: toward1.normalized, dashRequested: toward1.length < 1.4)
            if engine.step(inputs: inputs).contains(where: { if case .shoved = $0 { return true }; return false }) {
                break
            }
        }
        XCTAssertTrue(engine.state.players[1].isStaggered)

        MatchFixture.idle(&engine, steps: MatchFixture.steps(forSeconds: tuning.staggerDuration + 0.02))
        XCTAssertFalse(engine.state.players[1].isStaggered)
    }

    func testAStaggeredPlayerCannotKickOrDash() {
        var engine = MatchFixture.engine()
        for _ in 0..<MatchFixture.steps(forSeconds: 6) {
            var inputs = [PlayerInput](repeating: .idle, count: 5)
            let toward1 = (engine.state.players[1].body.position - engine.state.players[0].body.position)
            inputs[0] = PlayerInput(move: toward1.normalized, dashRequested: toward1.length < 1.4)
            if engine.step(inputs: inputs).contains(where: { if case .shoved = $0 { return true }; return false }) {
                break
            }
        }
        XCTAssertTrue(engine.state.players[1].isStaggered)

        var inputs = [PlayerInput](repeating: .idle, count: 5)
        inputs[1] = PlayerInput(kickHeld: true, dashRequested: true)
        let events = engine.step(inputs: inputs)
        XCTAssertFalse(events.contains(.dashed(player: 1)))
        XCTAssertEqual(engine.state.players[1].charge, 0)
    }

    // MARK: Containment through the engine

    func testNobodyCanLeaveTheCircleUnderAnyInput() {
        var engine = MatchFixture.engine()
        var rng = SeededRandom(seed: 99)
        let limit = tuning.pitchRadius - tuning.playerRadius

        for _ in 0..<MatchFixture.steps(forSeconds: 40) {
            let inputs = (0..<5).map { _ in
                PlayerInput(move: Vec2(angle: rng.double(in: -.pi ... .pi)),
                            kickHeld: rng.bool(chance: 0.3),
                            kickReleased: rng.bool(chance: 0.1),
                            dashRequested: rng.bool(chance: 0.05))
            }
            engine.step(inputs: inputs)

            for player in engine.state.players where player.isAlive {
                XCTAssertLessThanOrEqual(player.body.position.length, limit + 1e-6)
                XCTAssertFalse(player.body.position.x.isNaN)
            }

            // The ball is only inside the line while the ball is in play. A goal leaves it
            // sitting past the paint for the whole celebration, because that is what being in
            // the net means — asserting through a goal was measuring the net, not the rule.
            guard engine.state.phase.isPlaying else { continue }
            XCTAssertLessThanOrEqual(engine.state.ball.position.length,
                                     tuning.pitchRadius + 1e-6)
        }
    }

    /// A tap has to produce a full-blooded shot, not the 0%-charge minimum — the thumbs hold
    /// nothing down, so there is no charge for the engine to read.
    func testAnExplicitPowerOverridesTheCharge() {
        var engine = MatchFixture.engine()
        var inputs = [PlayerInput](repeating: .idle, count: 5)

        var struck: Double?
        for _ in 0..<MatchFixture.steps(forSeconds: 8) {
            let me = engine.state.players[0]
            inputs[0] = PlayerInput(move: (engine.state.ball.position - me.body.position).normalized)

            if KickResolver.canStrike(body: me.body, ball: engine.state.ball, tuning: tuning) {
                inputs[0].kickReleased = true
                inputs[0].kickPower = 1
            }
            for event in engine.step(inputs: inputs) {
                if case .kicked(0, let power) = event { struck = power }
            }
            if struck != nil { break }
        }
        XCTAssertEqual(struck, 1, "a tap is a full-power shot without ever holding the button")
        XCTAssertEqual(engine.state.ball.velocity.length, tuning.kickMaxSpeed, accuracy: 1e-6)
    }

    /// Without an explicit power the charge still decides, which is the path the bots use to
    /// vary power by range.
    func testWithoutAnExplicitPowerTheChargeStillDecides() {
        var engine = MatchFixture.engine()
        var inputs = [PlayerInput](repeating: .idle, count: 5)
        let holdSteps = 24   // 0.2 s of a 0.55 s charge

        // Walk up to the ball with the button untouched, so nothing has charged yet.
        for _ in 0..<MatchFixture.steps(forSeconds: 8) {
            let me = engine.state.players[0]
            inputs[0] = PlayerInput(move: (engine.state.ball.position - me.body.position).normalized)
            engine.step(inputs: inputs)
            if KickResolver.canStrike(body: engine.state.players[0].body,
                                      ball: engine.state.ball, tuning: tuning) { break }
        }

        // Now hold for a known time and let go, supplying no power of our own.
        inputs[0].move = .zero
        inputs[0].kickHeld = true
        for _ in 0..<holdSteps { engine.step(inputs: inputs) }

        inputs[0].kickHeld = false
        inputs[0].kickReleased = true
        var struck: Double?
        for event in engine.step(inputs: inputs) {
            if case .kicked(0, let power) = event { struck = power }
        }

        let expected = Double(holdSteps) * tuning.fixedStep / tuning.kickChargeTime
        XCTAssertEqual(struck ?? -1, expected, accuracy: 0.05,
                       "power came from the charge, not from a supplied value")
    }
}
