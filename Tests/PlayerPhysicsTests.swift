import XCTest
@testable import Svinjara

final class PlayerPhysicsTests: XCTestCase {

    private let tuning = Tuning.default

    private func run(_ body: inout PlayerBody, move: Vec2, seconds: Double) {
        for _ in 0..<Int((seconds / tuning.fixedStep).rounded()) {
            PlayerPhysics.integrate(&body, move: move, dash: nil, control: 1,
                                    dt: tuning.fixedStep, tuning: tuning)
        }
    }

    func testReachesTopSpeedInTheDocumentedTime() {
        var body = PlayerBody()
        run(&body, move: Vec2(x: 1, y: 0), seconds: tuning.timeToTopSpeed + 0.02)
        XCTAssertEqual(body.velocity.length, tuning.playerTopSpeed, accuracy: 0.05)
    }

    func testNeverExceedsTopSpeed() {
        var body = PlayerBody()
        run(&body, move: Vec2(x: 1, y: 0), seconds: 5)
        XCTAssertLessThanOrEqual(body.velocity.length, tuning.playerTopSpeed + 1e-9)
    }

    func testStopsInTheDocumentedTime() {
        var body = PlayerBody(position: .zero,
                              velocity: Vec2(x: tuning.playerTopSpeed, y: 0),
                              facing: 0)
        run(&body, move: .zero, seconds: tuning.timeToStop + 0.05)
        XCTAssertLessThan(body.velocity.length, tuning.playerTopSpeed * 0.02)
    }

    /// A partly-pushed stick means a lower top speed, not a lower acceleration — that is what
    /// makes a virtual joystick feel precise rather than mushy.
    func testPartialInputCapsSpeedProportionally() {
        var body = PlayerBody()
        run(&body, move: Vec2(x: 0.5, y: 0), seconds: 3)
        XCTAssertEqual(body.velocity.length, tuning.playerTopSpeed * 0.5, accuracy: 0.05)
    }

    func testFacingTurnsRatherThanSnapping() {
        var body = PlayerBody(position: .zero, velocity: .zero, facing: 0)
        // One step cannot turn further than the turn rate allows.
        PlayerPhysics.integrate(&body, move: Vec2(x: -1, y: 0), dash: nil, control: 1,
                                dt: tuning.fixedStep, tuning: tuning)
        XCTAssertEqual(abs(Angles.delta(from: 0, to: body.facing)),
                       tuning.playerTurnRate * tuning.fixedStep, accuracy: 1e-12)
    }

    func testFacingEventuallyArrives() {
        var body = PlayerBody(position: .zero, velocity: .zero, facing: 0)
        run(&body, move: Vec2(x: 0, y: 1), seconds: 1)
        XCTAssertEqual(Angles.separation(body.facing, .pi / 2), 0, accuracy: 1e-9)
    }

    func testZeroInputDoesNotProduceNaN() {
        var body = PlayerBody()
        run(&body, move: .zero, seconds: 1)
        XCTAssertFalse(body.position.x.isNaN)
        XCTAssertFalse(body.facing.isNaN)
        XCTAssertEqual(body.position, .zero)
    }

    /// A dash is a committed lunge: the stick is ignored for its duration, which is what makes
    /// mistiming one cost you.
    func testDashOverridesSteering() {
        var body = PlayerBody(position: .zero, velocity: .zero, facing: 0)
        PlayerPhysics.integrate(&body, move: Vec2(x: -1, y: 0), dash: Vec2(x: 1, y: 0),
                                control: 1, dt: tuning.fixedStep, tuning: tuning)
        XCTAssertEqual(body.velocity.x, tuning.dashSpeed, accuracy: 1e-12)
        XCTAssertEqual(body.facing, 0, accuracy: 1e-12)
    }

    func testDashCoversTheDocumentedDistance() {
        var body = PlayerBody()
        for _ in 0..<Int((tuning.dashDuration / tuning.fixedStep).rounded()) {
            PlayerPhysics.integrate(&body, move: .zero, dash: Vec2(x: 1, y: 0), control: 1,
                                    dt: tuning.fixedStep, tuning: tuning)
        }
        XCTAssertEqual(body.position.length, tuning.dashDistance, accuracy: 0.05)
    }

    func testStaggerReducesSteeringAuthority() {
        var free = PlayerBody()
        var staggered = PlayerBody()
        for _ in 0..<120 {
            PlayerPhysics.integrate(&free, move: Vec2(x: 1, y: 0), dash: nil, control: 1,
                                    dt: tuning.fixedStep, tuning: tuning)
            PlayerPhysics.integrate(&staggered, move: Vec2(x: 1, y: 0), dash: nil,
                                    control: tuning.staggerControl,
                                    dt: tuning.fixedStep, tuning: tuning)
        }
        XCTAssertLessThan(staggered.velocity.length, free.velocity.length * 0.5)
    }

    // MARK: Containment (story B2)

    func testAPlayerDrivenOutwardNeverLeavesTheCircle() {
        let arena = ArenaGeometry(tuning: tuning)
        let limit = arena.radius - tuning.playerRadius

        for bearing in stride(from: -Double.pi, to: Double.pi, by: 0.2) {
            var body = PlayerBody()
            let outward = Vec2(angle: bearing)
            for _ in 0..<Int(5.0 / tuning.fixedStep) {
                PlayerPhysics.integrate(&body, move: outward, dash: nil, control: 1,
                                        dt: tuning.fixedStep, tuning: tuning)
                CollisionSolver.slideInsideBoundary(position: &body.position,
                                                    velocity: &body.velocity,
                                                    boundaryRadius: arena.radius,
                                                    bodyRadius: tuning.playerRadius)
                XCTAssertLessThanOrEqual(body.position.length, limit + 1e-9)
            }
        }
    }

    /// Goal mouths are not doorways for players — story B2.
    func testAPlayerIsStoppedByAGoalMouthJustLikeWall() {
        let arena = ArenaGeometry(tuning: tuning)
        var body = PlayerBody()
        let towardOwnGoal = Vec2(angle: arena.bearings[0])

        for _ in 0..<Int(5.0 / tuning.fixedStep) {
            PlayerPhysics.integrate(&body, move: towardOwnGoal, dash: nil, control: 1,
                                    dt: tuning.fixedStep, tuning: tuning)
            CollisionSolver.slideInsideBoundary(position: &body.position,
                                                velocity: &body.velocity,
                                                boundaryRadius: arena.radius,
                                                bodyRadius: tuning.playerRadius)
        }
        XCTAssertEqual(body.position.length, arena.radius - tuning.playerRadius, accuracy: 1e-9)
    }

    func testRunningAtTheLineDiagonallySlidesAlongIt() {
        let arena = ArenaGeometry(tuning: tuning)
        var body = PlayerBody(position: Vec2(x: arena.radius - tuning.playerRadius, y: 0),
                              velocity: .zero, facing: 0)
        // 45° into the line.
        let move = Vec2(x: 1, y: 1).normalized

        for _ in 0..<120 {
            PlayerPhysics.integrate(&body, move: move, dash: nil, control: 1,
                                    dt: tuning.fixedStep, tuning: tuning)
            CollisionSolver.slideInsideBoundary(position: &body.position,
                                                velocity: &body.velocity,
                                                boundaryRadius: arena.radius,
                                                bodyRadius: tuning.playerRadius)
        }
        XCTAssertGreaterThan(body.position.y, 1.5, "kept moving along the line")
        XCTAssertEqual(body.position.length, arena.radius - tuning.playerRadius, accuracy: 1e-6)
    }
}
