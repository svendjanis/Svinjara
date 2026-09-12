import XCTest
@testable import Svinjara

final class GoalDetectorTests: XCTestCase {

    private let tuning = Tuning.default

    /// Story D1: a full-power shot through a mouth must count on the step it goes through.
    func testAFullPowerShotThroughTheMouthScoresInOneStep() {
        let arena = ArenaGeometry(tuning: tuning)
        let goal = 2
        let bearing = arena.bearings[goal]

        var ball = BallState(position: Vec2(angle: bearing, length: arena.radius - tuning.ballRadius),
                             velocity: Vec2(angle: bearing, length: tuning.kickMaxSpeed))

        let outcome = GoalDetector.advance(ball: &ball, arena: arena,
                                           dt: tuning.fixedStep, tuning: tuning)
        XCTAssertEqual(outcome, .scored(goal: goal))
    }

    func testEveryGoalCanBeScoredIn() {
        let arena = ArenaGeometry(tuning: tuning)
        for goal in 0..<arena.goalCount {
            let bearing = arena.bearings[goal]
            var ball = BallState(position: Vec2(angle: bearing, length: 6),
                                 velocity: Vec2(angle: bearing, length: tuning.kickMaxSpeed))
            var scored: Int?
            for _ in 0..<200 {
                if case .scored(let conceding) = GoalDetector.advance(ball: &ball, arena: arena,
                                                                      dt: tuning.fixedStep,
                                                                      tuning: tuning) {
                    scored = conceding
                    break
                }
            }
            XCTAssertEqual(scored, goal)
        }
    }

    func testAShotAtSolidLineReboundsAndScoresNothing() {
        let arena = ArenaGeometry(tuning: tuning)
        // Exactly between two mouths.
        let wall = Angles.normalize((arena.bearings[0] + arena.bearings[1]) / 2)
        var ball = BallState(position: Vec2(angle: wall, length: 6),
                             velocity: Vec2(angle: wall, length: tuning.kickMaxSpeed))

        var bounced = false
        for _ in 0..<200 {
            let outcome = GoalDetector.advance(ball: &ball, arena: arena,
                                               dt: tuning.fixedStep, tuning: tuning)
            if case .scored = outcome { return XCTFail("scored against solid line") }
            if outcome == .bounced { bounced = true; break }
        }
        XCTAssertTrue(bounced)
    }

    /// Story D1 and D3: a sealed arc is wall, and scoring into it is impossible.
    func testAShotAtASealedGoalRebounds() {
        var arena = ArenaGeometry(tuning: tuning)
        arena.seal(3)
        let bearing = arena.bearings[3]

        var ball = BallState(position: Vec2(angle: bearing, length: 6),
                             velocity: Vec2(angle: bearing, length: tuning.kickMaxSpeed))

        var bounced = false
        for _ in 0..<200 {
            let outcome = GoalDetector.advance(ball: &ball, arena: arena,
                                               dt: tuning.fixedStep, tuning: tuning)
            if case .scored = outcome { return XCTFail("scored into a bricked-up goal") }
            if outcome == .bounced { bounced = true; break }
        }
        XCTAssertTrue(bounced)
        XCTAssertLessThanOrEqual(ball.position.length, arena.radius - tuning.ballRadius + 1e-6)
    }

    func testAShotStraightAtAPostComesBackAndDoesNotScore() {
        let arena = ArenaGeometry(tuning: tuning)
        let post = arena.posts(of: 1).left
        let start = post.normalized * 6
        var ball = BallState(position: start,
                             velocity: (post - start).normalized * tuning.kickMaxSpeed)

        var hitPost = false
        for _ in 0..<200 {
            let outcome = GoalDetector.advance(ball: &ball, arena: arena,
                                               dt: tuning.fixedStep, tuning: tuning)
            if case .scored = outcome { return XCTFail("a shot onto the post must not score") }
            if outcome == .hitPost { hitPost = true; break }
        }
        XCTAssertTrue(hitPost)
        XCTAssertLessThan(ball.velocity.dot(post.normalized), 0, "sent back into play")
    }

    /// The ball's *centre* has to clear the paint. Sitting in the mouth is not a goal.
    func testSittingInTheMouthIsNotYetAGoal() {
        let arena = ArenaGeometry(tuning: tuning)
        let bearing = arena.bearings[0]
        // Past the rebound shell but not past the line, and barely moving.
        var ball = BallState(position: Vec2(angle: bearing, length: arena.radius - 0.05),
                             velocity: Vec2(angle: bearing, length: 0.05))

        let outcome = GoalDetector.advance(ball: &ball, arena: arena,
                                           dt: tuning.fixedStep, tuning: tuning)
        XCTAssertEqual(outcome, .none)
    }

    /// The rebound normal is the radius at the *contact point*, not at wherever the step
    /// happened to end. The two differ by up to 0.74°, which is small but free to get right.
    func testTheReboundUsesTheNormalAtContactNotAtTheEndpoint() {
        let arena = ArenaGeometry(tuning: tuning)
        let shell = arena.radius - tuning.ballRadius

        // A shallow approach to a stretch of solid line, so the bearing moves appreciably
        // across the step that makes contact.
        let wall = Angles.normalize((arena.bearings[0] + arena.bearings[1]) / 2)
        let start = Vec2(angle: wall - 0.06, length: shell - 0.05)
        let heading = Vec2(angle: wall).perpendicular.rotated(by: -1.2).normalized
        var ball = BallState(position: start, velocity: heading * tuning.kickMaxSpeed)

        let before = ball
        let outcome = GoalDetector.advance(ball: &ball, arena: arena,
                                           dt: tuning.fixedStep, tuning: tuning)
        XCTAssertEqual(outcome, .bounced)

        // Work the contact out independently and reflect about it.
        let damped = before.velocity * exp(-tuning.ballDamping * tuning.fixedStep)
        let travelled = before.position + damped * tuning.fixedStep
        guard let contact = CollisionSolver.outwardCrossing(from: before.position,
                                                            to: travelled,
                                                            radius: shell) else {
            return XCTFail("expected the ball to reach the line")
        }
        let contactNormal = -contact.point.normalized
        let expected = CollisionSolver.reflect(damped, normal: contactNormal,
                                               restitution: tuning.wallRestitution)
        XCTAssertEqual(Angles.separation(ball.velocity.angle, expected.angle), 0, accuracy: 1e-9)

        // And confirm the cheaper approximation really would have given a different answer,
        // so this test is not quietly passing for both.
        let endpointNormal = -travelled.normalized
        let approximate = CollisionSolver.reflect(damped, normal: endpointNormal,
                                                  restitution: tuning.wallRestitution)
        XCTAssertGreaterThan(Angles.separation(approximate.angle, expected.angle), 1e-4,
                             "the endpoint normal must actually differ, or this proves nothing")
    }

    /// A reassuring property of the geometry: a post's contact radius casts a wider angular
    /// shadow than the ball's bearing can swing in one step, so there is no band near a mouth
    /// edge where a goal verdict could be ambiguous — the post always gets there first.
    func testPostsShadowTheEntireMarginOfDoubt() {
        let arena = ArenaGeometry(tuning: tuning)
        let swingPerStep = tuning.ballMaxSpeed * tuning.fixedStep / arena.radius
        let postShadow = (tuning.ballRadius + arena.postRadius) / arena.radius
        XCTAssertGreaterThan(postShadow, swingPerStep)
    }
}
