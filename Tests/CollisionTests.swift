import XCTest
@testable import Svinjara

final class CollisionTests: XCTestCase {

    private let tuning = Tuning.default

    // MARK: Boundary crossing

    func testOutwardCrossingFindsTheExactPoint() {
        // Straight out along +x from the centre, through radius 10.
        guard let crossing = CollisionSolver.outwardCrossing(from: Vec2(x: 0, y: 0),
                                                             to: Vec2(x: 20, y: 0),
                                                             radius: 10) else {
            return XCTFail("expected a crossing")
        }
        XCTAssertEqual(crossing.point.x, 10, accuracy: 1e-12)
        XCTAssertEqual(crossing.fraction, 0.5, accuracy: 1e-12)
    }

    func testOutwardCrossingMissesWhenTheStepStaysInside() {
        XCTAssertNil(CollisionSolver.outwardCrossing(from: Vec2(x: 0, y: 0),
                                                     to: Vec2(x: 5, y: 0),
                                                     radius: 10))
    }

    func testOutwardCrossingReportsImmediateContactWhenAlreadyOutside() {
        let crossing = CollisionSolver.outwardCrossing(from: Vec2(x: 11, y: 0),
                                                       to: Vec2(x: 12, y: 0),
                                                       radius: 10)
        XCTAssertEqual(crossing?.fraction, 0)
        XCTAssertEqual(crossing?.point, Vec2(x: 11, y: 0))
    }

    /// A chord that clips the circle: the crossing bearing is the one that matters for goals,
    /// and it is nowhere near either endpoint's bearing.
    func testCrossingBearingIsTakenAtTheCrossingNotAtAnEndpoint() {
        let p0 = Vec2(x: -5, y: 9.5)
        let p1 = Vec2(x: 5, y: 9.5)
        let crossing = CollisionSolver.outwardCrossing(from: p0, to: p1, radius: 11)
        XCTAssertNil(crossing, "this chord never reaches radius 11")

        let out0 = Vec2(x: 0, y: 10.5)
        let out1 = Vec2(x: 4, y: 11.5)
        let hit = CollisionSolver.outwardCrossing(from: out0, to: out1, radius: 11)
        XCTAssertNotNil(hit)
        XCTAssertEqual(hit!.point.length, 11, accuracy: 1e-9)
        XCTAssertNotEqual(hit!.bearing, out0.angle, accuracy: 1e-6)
        XCTAssertNotEqual(hit!.bearing, out1.angle, accuracy: 1e-6)
    }

    // MARK: Reflection

    func testAngleOfIncidenceEqualsAngleOfReflection() {
        let normal = Vec2(x: 0, y: 1)
        for incidence in stride(from: 0.05, to: Double.pi / 2 - 0.05, by: 0.1) {
            let velocity = Vec2(angle: -Double.pi / 2 + incidence, length: 9)
            let reflected = CollisionSolver.reflect(velocity, normal: normal, restitution: 1)
            XCTAssertEqual(abs(velocity.dot(normal)), abs(reflected.dot(normal)), accuracy: 1e-12)
            XCTAssertEqual(velocity.dot(normal.perpendicular),
                           reflected.dot(normal.perpendicular), accuracy: 1e-12)
            XCTAssertEqual(velocity.length, reflected.length, accuracy: 1e-12)
        }
    }

    func testReflectionLosesEnergy() {
        let reflected = CollisionSolver.reflect(Vec2(x: 0, y: -10),
                                                normal: Vec2(x: 0, y: 1),
                                                restitution: tuning.wallRestitution)
        XCTAssertEqual(reflected.length, 10 * tuning.wallRestitution, accuracy: 1e-12)
    }

    /// A body already moving away must be left alone, or a slightly embedded one gets
    /// reflected on consecutive steps and jitters against the surface.
    func testReflectionIgnoresABodyAlreadyLeaving() {
        let leaving = Vec2(x: 0, y: 4)
        XCTAssertEqual(CollisionSolver.reflect(leaving, normal: Vec2(x: 0, y: 1), restitution: 0.5),
                       leaving)
    }

    // MARK: Containment

    func testPlayersSlideAlongTheLineRatherThanBouncing() {
        var position = Vec2(x: 11, y: 0)
        // Running diagonally into the line: outward and along it at once.
        var velocity = Vec2(x: 4, y: 3)

        let touched = CollisionSolver.slideInsideBoundary(position: &position,
                                                          velocity: &velocity,
                                                          boundaryRadius: tuning.pitchRadius,
                                                          bodyRadius: tuning.playerRadius)

        XCTAssertTrue(touched)
        XCTAssertEqual(position.length, tuning.pitchRadius - tuning.playerRadius, accuracy: 1e-12)
        XCTAssertEqual(velocity.x, 0, accuracy: 1e-12, "radial component removed")
        XCTAssertEqual(velocity.y, 3, accuracy: 1e-12, "tangential component kept")
    }

    func testSlidingIgnoresAPlayerWellInside() {
        var position = Vec2(x: 1, y: 1)
        var velocity = Vec2(x: 5, y: 0)
        XCTAssertFalse(CollisionSolver.slideInsideBoundary(position: &position,
                                                           velocity: &velocity,
                                                           boundaryRadius: tuning.pitchRadius,
                                                           bodyRadius: tuning.playerRadius))
        XCTAssertEqual(position, Vec2(x: 1, y: 1))
        XCTAssertEqual(velocity, Vec2(x: 5, y: 0))
    }

    // MARK: Disc against disc

    func testEqualMassHeadOnExchangeIsSymmetric() {
        var posA = Vec2(x: -0.4, y: 0), velA = Vec2(x: 2, y: 0)
        var posB = Vec2(x: 0.4, y: 0), velB = Vec2(x: -2, y: 0)

        let touched = CollisionSolver.resolveEqualMass(positionA: &posA, velocityA: &velA,
                                                       positionB: &posB, velocityB: &velB,
                                                       radiusA: 0.42, radiusB: 0.42,
                                                       restitution: 1)
        XCTAssertTrue(touched)
        // Perfectly elastic, equal mass, head on: they swap.
        XCTAssertEqual(velA.x, -2, accuracy: 1e-12)
        XCTAssertEqual(velB.x, 2, accuracy: 1e-12)
        XCTAssertEqual(posB.x - posA.x, 0.84, accuracy: 1e-12, "overlap resolved")
    }

    func testBodiesAreSeparatedAndMomentumIsConserved() {
        var posA = Vec2(x: 0, y: 0), velA = Vec2(x: 3, y: 1)
        var posB = Vec2(x: 0.5, y: 0.2), velB = Vec2(x: -1, y: 0.5)
        let momentumBefore = velA + velB

        CollisionSolver.resolveEqualMass(positionA: &posA, velocityA: &velA,
                                         positionB: &posB, velocityB: &velB,
                                         radiusA: 0.42, radiusB: 0.42,
                                         restitution: tuning.playerRestitution)

        XCTAssertEqual(posA.distance(to: posB), 0.84, accuracy: 1e-12)
        let momentumAfter = velA + velB
        XCTAssertEqual(momentumAfter.x, momentumBefore.x, accuracy: 1e-12)
        XCTAssertEqual(momentumAfter.y, momentumBefore.y, accuracy: 1e-12)
    }

    func testCoincidentBodiesAreSeparatedRatherThanProducingNaN() {
        var posA = Vec2.zero, velA = Vec2.zero
        var posB = Vec2.zero, velB = Vec2.zero
        CollisionSolver.resolveEqualMass(positionA: &posA, velocityA: &velA,
                                         positionB: &posB, velocityB: &velB,
                                         radiusA: 0.42, radiusB: 0.42, restitution: 0.3)
        XCTAssertEqual(posA.distance(to: posB), 0.84, accuracy: 1e-12)
        XCTAssertFalse(posA.x.isNaN)
    }

    func testNonTouchingDiscsAreUntouched() {
        var posA = Vec2(x: -5, y: 0), velA = Vec2(x: 1, y: 0)
        var posB = Vec2(x: 5, y: 0), velB = Vec2(x: -1, y: 0)
        XCTAssertFalse(CollisionSolver.resolveEqualMass(positionA: &posA, velocityA: &velA,
                                                        positionB: &posB, velocityB: &velB,
                                                        radiusA: 0.42, radiusB: 0.42,
                                                        restitution: 0.3))
    }

    // MARK: Posts

    func testBallAimedAtAPostCentreComesStraightBack() {
        let post = Vec2(x: 5, y: 0)
        var position = Vec2(x: 4.0, y: 0)
        var velocity = Vec2(x: 12, y: 0)
        let previous = position
        position += velocity * tuning.fixedStep

        let hit = CollisionSolver.resolveAgainstStatic(previous: previous,
                                                       position: &position,
                                                       velocity: &velocity,
                                                       bodyRadius: tuning.ballRadius,
                                                       centre: post,
                                                       staticRadius: tuning.postRadius,
                                                       restitution: tuning.postRestitution,
                                                       dt: tuning.fixedStep)
        XCTAssertFalse(hit, "still 0.9 m short after one step")

        // Walk it in until it does connect.
        var struck = false
        for _ in 0..<200 {
            let from = position
            position += velocity * tuning.fixedStep
            if CollisionSolver.resolveAgainstStatic(previous: from,
                                                    position: &position,
                                                    velocity: &velocity,
                                                    bodyRadius: tuning.ballRadius,
                                                    centre: post,
                                                    staticRadius: tuning.postRadius,
                                                    restitution: tuning.postRestitution,
                                                    dt: tuning.fixedStep) {
                struck = true
                break
            }
        }
        XCTAssertTrue(struck)
        XCTAssertEqual(velocity.x, -12 * tuning.postRestitution, accuracy: 1e-9)
        XCTAssertEqual(velocity.y, 0, accuracy: 1e-9)
    }

    /// The reason the post test is swept. At 120 Hz nothing tunnels clean through a post, but
    /// a path that clips its edge can enter and leave the contact radius inside one step —
    /// both endpoints outside, contact in the middle. An endpoint-only test would silently
    /// drop exactly the deflections a player notices.
    func testAGrazingPathIsCaughtEvenThoughBothEndpointsAreClear() {
        let post = Vec2(x: 3, y: 0)
        let contactRadius = tuning.ballRadius + tuning.postRadius
        let step = tuning.kickMaxSpeed * tuning.fixedStep

        // Offset chosen so the chord through the contact circle is shorter than one step.
        let offset = 0.222
        let halfChord = (contactRadius * contactRadius - offset * offset).squareRoot()
        XCTAssertLessThan(2 * halfChord, step, "this path must clear the post within one step")

        var position = Vec2(x: post.x - halfChord - 0.01, y: offset)
        var velocity = Vec2(x: tuning.kickMaxSpeed, y: 0)
        let previous = position
        position += velocity * tuning.fixedStep

        XCTAssertGreaterThan(previous.distance(to: post), contactRadius, "starts clear")
        XCTAssertGreaterThan(position.distance(to: post), contactRadius, "ends clear")

        let hit = CollisionSolver.resolveAgainstStatic(previous: previous,
                                                       position: &position,
                                                       velocity: &velocity,
                                                       bodyRadius: tuning.ballRadius,
                                                       centre: post,
                                                       staticRadius: tuning.postRadius,
                                                       restitution: tuning.postRestitution,
                                                       dt: tuning.fixedStep)
        XCTAssertTrue(hit, "the swept test must catch what the endpoints missed")
        XCTAssertGreaterThan(velocity.y, 0, "deflected away from the post")
    }

    /// At the speeds and step this game actually runs at, a post cannot be skipped over.
    func testNoLegalShotCanCrossAPostInOneStep() {
        let contactDiameter = 2 * (tuning.ballRadius + tuning.postRadius)
        let fastestStep = tuning.ballMaxSpeed * tuning.fixedStep
        XCTAssertLessThan(fastestStep, contactDiameter,
                          "if this ever fails, sub-stepping is required")
    }

    func testGlancingAPostDeflectsSideways() {
        let post = Vec2(x: 3, y: 0)
        var position = Vec2(x: 2.0, y: 0.20)
        var velocity = Vec2(x: 10, y: 0)

        var hit = false
        for _ in 0..<200 {
            let from = position
            position += velocity * tuning.fixedStep
            if CollisionSolver.resolveAgainstStatic(previous: from,
                                                    position: &position,
                                                    velocity: &velocity,
                                                    bodyRadius: tuning.ballRadius,
                                                    centre: post,
                                                    staticRadius: tuning.postRadius,
                                                    restitution: tuning.postRestitution,
                                                    dt: tuning.fixedStep) {
                hit = true
                break
            }
        }
        XCTAssertTrue(hit)
        XCTAssertGreaterThan(velocity.y, 0.5, "pushed off to the side rather than straight back")
    }
}
