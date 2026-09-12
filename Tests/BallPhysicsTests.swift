import XCTest
@testable import Svinjara

final class BallPhysicsTests: XCTestCase {

    private let tuning = Tuning.default

    /// Every goal sealed: a closed container, so nothing can legitimately leave.
    private func sealedArena() -> ArenaGeometry {
        var arena = ArenaGeometry(tuning: tuning)
        for goal in 0..<arena.goalCount { arena.seal(goal) }
        return arena
    }

    // MARK: Damping

    func testDampingDecaysExponentially() {
        var ball = BallState(position: .zero, velocity: Vec2(x: 10, y: 0))
        let seconds = 1.0
        for _ in 0..<Int(seconds / tuning.fixedStep) {
            BallPhysics.integrate(&ball, dt: tuning.fixedStep, tuning: tuning)
        }
        XCTAssertEqual(ball.velocity.x, 10 * exp(-tuning.ballDamping * seconds), accuracy: 0.02)
    }

    /// Concrete, not grass: a struck ball is still moving properly after two seconds.
    func testAStruckBallStillCarriesAfterTwoSeconds() {
        var ball = BallState(position: .zero, velocity: Vec2(x: tuning.kickMaxSpeed, y: 0))
        for _ in 0..<Int(2.0 / tuning.fixedStep) {
            BallPhysics.integrate(&ball, dt: tuning.fixedStep, tuning: tuning)
        }
        XCTAssertGreaterThan(ball.velocity.length, 4)
    }

    func testABallBelowTheRestThresholdIsStopped() {
        var ball = BallState(position: .zero, velocity: Vec2(x: 0.1, y: 0))
        BallPhysics.integrate(&ball, dt: tuning.fixedStep, tuning: tuning)
        XCTAssertTrue(ball.isAtRest)
    }

    func testSpeedIsCapped() {
        var ball = BallState(position: .zero, velocity: Vec2(x: 500, y: 0))
        BallPhysics.integrate(&ball, dt: tuning.fixedStep, tuning: tuning)
        XCTAssertLessThanOrEqual(ball.velocity.length, tuning.ballMaxSpeed + 1e-9)
    }

    func testIntegrateReturnsWhereTheStepStarted() {
        var ball = BallState(position: Vec2(x: 1, y: 2), velocity: Vec2(x: 3, y: 0))
        let previous = BallPhysics.integrate(&ball, dt: tuning.fixedStep, tuning: tuning)
        XCTAssertEqual(previous, Vec2(x: 1, y: 2))
        XCTAssertNotEqual(ball.position, previous)
    }

    // MARK: Rebounds

    func testTheBallReboundsOffTheLine() {
        let arena = sealedArena()
        var ball = BallState(position: Vec2(x: 10.0, y: 0), velocity: Vec2(x: 8, y: 0))

        var bounced = false
        for _ in 0..<200 {
            if GoalDetector.advance(ball: &ball, arena: arena, dt: tuning.fixedStep, tuning: tuning) == .bounced {
                bounced = true
                break
            }
        }
        XCTAssertTrue(bounced)
        XCTAssertLessThan(ball.velocity.x, 0, "sent back toward the middle")
    }

    func testABounceAlwaysLosesSpeed() {
        let arena = sealedArena()
        var ball = BallState(position: .zero, velocity: Vec2(angle: 0.7, length: 15))

        var previousSpeed = ball.velocity.length
        for _ in 0..<5_000 {
            let outcome = GoalDetector.advance(ball: &ball, arena: arena, dt: tuning.fixedStep, tuning: tuning)
            let speed = ball.velocity.length
            XCTAssertLessThanOrEqual(speed, previousSpeed + 1e-9,
                                     "a \(outcome) must never add energy")
            previousSpeed = speed
        }
    }

    /// The containment property, hammered from every direction: the ball must not escape a
    /// sealed circle, whatever angle or speed it is struck at.
    func testTenThousandShotsNeverLeaveASealedCircle() {
        let arena = sealedArena()
        var rng = SeededRandom(seed: 20260912)

        for shot in 0..<10_000 {
            var ball = BallState(position: Vec2(angle: rng.double(in: -.pi ... .pi),
                                                length: rng.double(in: 0...9.5)),
                                 velocity: Vec2(angle: rng.double(in: -.pi ... .pi),
                                                length: rng.double(in: 1...tuning.ballMaxSpeed)))
            for _ in 0..<240 {
                let outcome = GoalDetector.advance(ball: &ball, arena: arena,
                                                   dt: tuning.fixedStep, tuning: tuning)
                XCTAssertNotEqual(outcome, .scored(goal: 0), "no goal is open")

                let limit = arena.radius - tuning.ballRadius
                XCTAssertLessThanOrEqual(ball.position.length, limit + 1e-6,
                                         "shot \(shot) escaped at \(ball.position)")
                XCTAssertFalse(ball.position.x.isNaN, "shot \(shot) produced NaN")
            }
        }
    }

    /// A resting ball against the line must not be re-reflected every step and jitter.
    func testABallRestingOnTheLineStaysPut() {
        let arena = sealedArena()
        let limit = arena.radius - tuning.ballRadius
        var ball = BallState(position: Vec2(x: limit, y: 0), velocity: .zero)

        for _ in 0..<600 {
            GoalDetector.advance(ball: &ball, arena: arena, dt: tuning.fixedStep, tuning: tuning)
        }
        XCTAssertEqual(ball.position.x, limit, accuracy: 1e-6)
        XCTAssertTrue(ball.isAtRest)
    }
}
