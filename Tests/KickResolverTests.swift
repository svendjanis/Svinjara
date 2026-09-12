import XCTest
@testable import Svinjara

final class KickResolverTests: XCTestCase {

    private let tuning = Tuning.default
    private let arena = ArenaGeometry(tuning: .default)

    private func facingRight(at position: Vec2 = .zero) -> PlayerBody {
        PlayerBody(position: position, velocity: .zero, facing: 0)
    }

    // MARK: Range and arc

    func testTheBallMustBeWithinReach() {
        let body = facingRight()
        let near = BallState(position: Vec2(x: tuning.kickReach - 0.01, y: 0))
        let far = BallState(position: Vec2(x: tuning.kickReach + 0.01, y: 0))
        XCTAssertTrue(KickResolver.canStrike(body: body, ball: near, tuning: tuning))
        XCTAssertFalse(KickResolver.canStrike(body: body, ball: far, tuning: tuning))
    }

    func testTheBallMustBeInFrontOfYou() {
        let body = facingRight()
        let distance = tuning.kickReach - 0.05
        // Just inside the ±60° arc, and just outside it.
        let inside = BallState(position: Vec2(angle: tuning.kickArc - 0.02, length: distance))
        let outside = BallState(position: Vec2(angle: tuning.kickArc + 0.02, length: distance))
        XCTAssertTrue(KickResolver.canStrike(body: body, ball: inside, tuning: tuning))
        XCTAssertFalse(KickResolver.canStrike(body: body, ball: outside, tuning: tuning))
        // Directly behind is never kickable.
        XCTAssertFalse(KickResolver.canStrike(body: body,
                                              ball: BallState(position: Vec2(x: -distance, y: 0)),
                                              tuning: tuning))
    }

    // MARK: Power

    func testPowerScalesLinearlyWithCharge() {
        XCTAssertEqual(KickResolver.speed(forCharge: 0, tuning: tuning),
                       tuning.kickMinSpeed, accuracy: 1e-12)
        XCTAssertEqual(KickResolver.speed(forCharge: tuning.kickChargeTime / 2, tuning: tuning),
                       (tuning.kickMinSpeed + tuning.kickMaxSpeed) / 2, accuracy: 1e-12)
        XCTAssertEqual(KickResolver.speed(forCharge: tuning.kickChargeTime, tuning: tuning),
                       tuning.kickMaxSpeed, accuracy: 1e-12)
    }

    func testOverchargingIsCapped() {
        XCTAssertEqual(KickResolver.speed(forCharge: 99, tuning: tuning),
                       tuning.kickMaxSpeed, accuracy: 1e-12)
    }

    func testAFullChargeStrikesAlongTheFacing() {
        let body = PlayerBody(position: .zero, velocity: .zero, facing: 1.0)
        var ball = BallState(position: Vec2(angle: 1.0, length: 0.4))
        let event = KickResolver.strike(player: 2, body: body, charge: tuning.kickChargeTime,
                                        assisted: false, ball: &ball, arena: arena, tuning: tuning)

        XCTAssertEqual(event, .kicked(player: 2, power: 1))
        XCTAssertEqual(ball.velocity.length, tuning.kickMaxSpeed, accuracy: 1e-12)
        XCTAssertEqual(Angles.separation(ball.velocity.angle, 1.0), 0, accuracy: 1e-12)
        XCTAssertEqual(ball.lastTouchedBy, 2)
    }

    /// A bare tap has to feel like a shot. It used to produce a 3 m/s "soft touch", so the
    /// most natural way to try to shoot gave the least shot-like result.
    func testATapIsARealShot() {
        let body = facingRight()
        var ball = BallState(position: Vec2(x: 0.4, y: 0))

        let event = KickResolver.strike(player: 0, body: body, charge: 0, assisted: false,
                                        ball: &ball, arena: arena, tuning: tuning)
        XCTAssertEqual(event, .kicked(player: 0, power: 0))
        XCTAssertEqual(ball.velocity.length, tuning.kickMinSpeed, accuracy: 1e-12)
        XCTAssertGreaterThan(ball.velocity.length, 6, "a tap must actually go somewhere")
    }

    func testAnIllegalKickLeavesTheBallAlone() {
        let body = facingRight()
        let untouched = BallState(position: Vec2(x: -1, y: 0), velocity: Vec2(x: 2, y: 0))
        var ball = untouched

        XCTAssertNil(KickResolver.strike(player: 0, body: body, charge: tuning.kickChargeTime,
                                         assisted: false, ball: &ball, arena: arena, tuning: tuning))
        XCTAssertEqual(ball, untouched)
    }

    /// Velocity is replaced, not added to — otherwise volleying a ball that is already flying
    /// at you produces a rocket nobody aimed. `docs/RULES.md` §7.
    func testVolleyingDoesNotAddToTheBallsExistingSpeed() {
        let body = facingRight()
        // Ball already hurtling toward the kicker at full tilt.
        var ball = BallState(position: Vec2(x: 0.4, y: 0), velocity: Vec2(x: -20, y: 0))

        KickResolver.strike(player: 0, body: body, charge: tuning.kickChargeTime,
                            assisted: false, ball: &ball, arena: arena, tuning: tuning)

        XCTAssertEqual(ball.velocity.x, tuning.kickMaxSpeed, accuracy: 1e-12)
        XCTAssertLessThanOrEqual(ball.velocity.length, tuning.kickMaxSpeed + 1e-9)
    }

    // MARK: Body contact

    /// The ball leaves at less than your own speed on purpose. At 100% it runs away from you
    /// until rolling resistance brings it back, which is what made carrying it feel like
    /// herding rather than dribbling.
    func testRunningIntoTheBallCarriesItButNotAway() {
        let body = PlayerBody(position: .zero, velocity: Vec2(x: 4, y: 0), facing: 0)
        var ball = BallState(position: Vec2(x: 0.4, y: 0))

        XCTAssertTrue(KickResolver.resolveBodyContact(player: 1, body: body, ball: &ball,
                                                      tuning: tuning))
        XCTAssertEqual(ball.velocity.x, 4 * tuning.dribbleGrip, accuracy: 1e-9)
        XCTAssertLessThan(ball.velocity.x, 4, "the ball must not outrun the player carrying it")
        XCTAssertEqual(ball.position.x, tuning.playerRadius + tuning.ballRadius, accuracy: 1e-12)
        XCTAssertEqual(ball.lastTouchedBy, 1)
    }

    /// Only the component going into the ball transfers — running past it must not fling it.
    func testRunningPastTheBallDoesNotFlingIt() {
        let body = PlayerBody(position: .zero, velocity: Vec2(x: 0, y: 5), facing: .pi / 2)
        var ball = BallState(position: Vec2(x: 0.4, y: 0))

        KickResolver.resolveBodyContact(player: 0, body: body, ball: &ball, tuning: tuning)
        XCTAssertEqual(ball.velocity.length, 0, accuracy: 1e-9)
    }

    func testContactNeverSlowsABallAlreadyMovingAwayFaster() {
        let body = PlayerBody(position: .zero, velocity: Vec2(x: 2, y: 0), facing: 0)
        var ball = BallState(position: Vec2(x: 0.4, y: 0), velocity: Vec2(x: 9, y: 0))

        KickResolver.resolveBodyContact(player: 0, body: body, ball: &ball, tuning: tuning)
        XCTAssertEqual(ball.velocity.x, 9, accuracy: 1e-12)
    }

    /// Story C3: the ball stays with you when you run in a straight line.
    func testDribblingKeepsTheBallWithinReach() {
        // Started at the far side and run across the middle: three seconds at top speed is
        // 16 m, so starting at the centre would put the player through the far wall.
        var body = PlayerBody(position: Vec2(x: -9.5, y: 0), velocity: .zero, facing: 0)
        var ball = BallState(position: Vec2(x: -9.0, y: 0))
        let arena = ArenaGeometry(tuning: tuning)

        for _ in 0..<Int(3.0 / tuning.fixedStep) {
            PlayerPhysics.integrate(&body, move: Vec2(x: 1, y: 0), dash: nil, control: 1,
                                    dt: tuning.fixedStep, tuning: tuning)
            CollisionSolver.slideInsideBoundary(position: &body.position,
                                                velocity: &body.velocity,
                                                boundaryRadius: arena.radius,
                                                bodyRadius: tuning.playerRadius)
            GoalDetector.advance(ball: &ball, arena: arena, dt: tuning.fixedStep, tuning: tuning)
            KickResolver.resolveBodyContact(player: 0, body: body, ball: &ball, tuning: tuning)

            XCTAssertLessThanOrEqual(body.position.distance(to: ball.position),
                                     tuning.kickReach + 1e-6,
                                     "lost the ball at x = \(body.position.x) m")
        }
    }

    // MARK: Aim assist

    /// A thumb cannot aim to the degree, so a shot roughly at a mouth is snapped onto it.
    func testAShotRoughlyAtAMouthIsSnappedOntoIt() {
        let target = 2
        let from = Vec2.zero
        let trueBearing = arena.aimBearing(from: from, at: target)
        let sloppy = trueBearing + 0.3   // ~17 degrees off, inside the 25 degree window

        let aimed = KickResolver.aim(facing: sloppy, from: from, shooter: 0, assisted: true,
                                     arena: arena, tuning: tuning)
        XCTAssertEqual(Angles.separation(aimed, trueBearing), 0, accuracy: 1e-9)
    }

    /// The assist window is 40° and the goals are 72° apart, so most headings are within reach
    /// of *some* mouth. The ones that are not are the ones that matter: your own goal is
    /// excluded, so hammering the ball away from your own line is never quietly turned into a
    /// shot at somebody sideways.
    func testClearingYourOwnLineIsNeverSnappedIntoAShot() {
        let from = Vec2(angle: arena.bearings[0], length: 7)
        // Facing straight at your own mouth: the nearest rival goal is far outside the window.
        let ownward = arena.aimBearing(from: from, at: 0)

        XCTAssertEqual(KickResolver.aim(facing: ownward, from: from, shooter: 0, assisted: true,
                                        arena: arena, tuning: tuning),
                       ownward)
    }

    func testTheWindowIsRespected() {
        let from = Vec2.zero
        let target = arena.aimBearing(from: from, at: 2)

        // Just inside the window snaps; a heading closer to a different mouth goes to that one
        // instead, never to a goal further away than the window allows.
        let aimed = KickResolver.aim(facing: target + tuning.aimAssistAngle * 0.9,
                                     from: from, shooter: 0, assisted: true,
                                     arena: arena, tuning: tuning)
        let offset = Angles.separation(aimed, target + tuning.aimAssistAngle * 0.9)
        XCTAssertLessThanOrEqual(offset, tuning.aimAssistAngle + 1e-9,
                                 "a shot is never bent further than the window")
    }

    func testAssistNeverSnapsOntoYourOwnGoal() {
        let from = Vec2(x: 0, y: -2)
        let ownBearing = arena.aimBearing(from: from, at: 0)
        let aimed = KickResolver.aim(facing: ownBearing, from: from, shooter: 0, assisted: true,
                                     arena: arena, tuning: tuning)
        XCTAssertEqual(aimed, ownBearing, "it may still go in — but not because we helped")
    }

    func testAssistNeverSnapsOntoASealedGoal() {
        var sealed = arena
        sealed.seal(3)
        let from = Vec2.zero
        let bearing = sealed.aimBearing(from: from, at: 3)
        XCTAssertEqual(KickResolver.aim(facing: bearing, from: from, shooter: 0, assisted: true,
                                        arena: sealed, tuning: tuning),
                       bearing)
    }

    func testAssistPicksTheNearestMouthNotJustAnyOne() {
        let from = Vec2.zero
        let near = arena.aimBearing(from: from, at: 1)
        let aimed = KickResolver.aim(facing: near + 0.2, from: from, shooter: 0, assisted: true,
                                     arena: arena, tuning: tuning)
        XCTAssertEqual(Angles.separation(aimed, near), 0, accuracy: 1e-9)
    }

    /// Bots do not ask for it, and must be unaffected — otherwise the aim-error setting that
    /// separates the difficulty tiers would be quietly cancelled out.
    func testAssistDoesNothingWhenItIsNotAskedFor() {
        let from = Vec2.zero
        let sloppy = arena.aimBearing(from: from, at: 2) + 0.3
        XCTAssertEqual(KickResolver.aim(facing: sloppy, from: from, shooter: 0, assisted: false,
                                        arena: arena, tuning: tuning),
                       sloppy)
    }

    func testAnAssistedStrikeLeavesOnTheAssistedBearing() {
        let target = 1
        var ball = BallState(position: Vec2(x: 0.4, y: 0))
        let trueBearing = arena.aimBearing(from: ball.position, at: target)
        let body = PlayerBody(position: .zero, velocity: .zero, facing: trueBearing + 0.25)

        // Place the ball in front of the striker so the kick is legal.
        ball.position = body.position + Vec2(angle: body.facing, length: 0.4)
        let corrected = arena.aimBearing(from: ball.position, at: target)

        KickResolver.strike(player: 0, body: body, charge: tuning.kickChargeTime,
                            assisted: true, ball: &ball, arena: arena, tuning: tuning)
        XCTAssertEqual(Angles.separation(ball.velocity.angle, corrected), 0, accuracy: 1e-6)
    }
}
