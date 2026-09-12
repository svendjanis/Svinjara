import XCTest
@testable import Svinjara

final class KickResolverTests: XCTestCase {

    private let tuning = Tuning.default

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
                                        ball: &ball, tuning: tuning)

        XCTAssertEqual(event, .kicked(player: 2, power: 1))
        XCTAssertEqual(ball.velocity.length, tuning.kickMaxSpeed, accuracy: 1e-12)
        XCTAssertEqual(Angles.separation(ball.velocity.angle, 1.0), 0, accuracy: 1e-12)
        XCTAssertEqual(ball.lastTouchedBy, 2)
    }

    func testALightTapIsASoftTouchNotAShot() {
        let body = facingRight()
        var ball = BallState(position: Vec2(x: 0.4, y: 0))
        let charge = tuning.kickChargeTime * (tuning.softTouchThreshold / 2)

        let event = KickResolver.strike(player: 0, body: body, charge: charge,
                                        ball: &ball, tuning: tuning)
        XCTAssertEqual(event, .softTouch(player: 0))
        XCTAssertEqual(ball.velocity.length, tuning.dribbleSpeed, accuracy: 1e-12)
    }

    func testAnIllegalKickLeavesTheBallAlone() {
        let body = facingRight()
        let untouched = BallState(position: Vec2(x: -1, y: 0), velocity: Vec2(x: 2, y: 0))
        var ball = untouched

        XCTAssertNil(KickResolver.strike(player: 0, body: body, charge: tuning.kickChargeTime,
                                         ball: &ball, tuning: tuning))
        XCTAssertEqual(ball, untouched)
    }

    /// Velocity is replaced, not added to — otherwise volleying a ball that is already flying
    /// at you produces a rocket nobody aimed. `docs/RULES.md` §7.
    func testVolleyingDoesNotAddToTheBallsExistingSpeed() {
        let body = facingRight()
        // Ball already hurtling toward the kicker at full tilt.
        var ball = BallState(position: Vec2(x: 0.4, y: 0), velocity: Vec2(x: -20, y: 0))

        KickResolver.strike(player: 0, body: body, charge: tuning.kickChargeTime,
                            ball: &ball, tuning: tuning)

        XCTAssertEqual(ball.velocity.x, tuning.kickMaxSpeed, accuracy: 1e-12)
        XCTAssertLessThanOrEqual(ball.velocity.length, tuning.kickMaxSpeed + 1e-9)
    }

    // MARK: Body contact

    func testRunningIntoTheBallCarriesIt() {
        let body = PlayerBody(position: .zero, velocity: Vec2(x: 4, y: 0), facing: 0)
        var ball = BallState(position: Vec2(x: 0.4, y: 0))

        XCTAssertTrue(KickResolver.resolveBodyContact(player: 1, body: body, ball: &ball,
                                                      tuning: tuning))
        XCTAssertEqual(ball.velocity.x, 4, accuracy: 1e-9)
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
}
