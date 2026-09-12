import XCTest
@testable import Svinjara

final class ArenaGeometryTests: XCTestCase {

    private let tuning = Tuning.default

    func testFiveGoalsEvenlySpaced() {
        let arena = ArenaGeometry(tuning: tuning)
        XCTAssertEqual(arena.goalCount, 5)

        let spacing = Angles.tau / 5
        for goal in 1..<arena.goalCount {
            XCTAssertEqual(Angles.separation(arena.bearings[goal], arena.bearings[goal - 1]),
                           spacing, accuracy: 1e-12)
        }
    }

    /// Goal 0 belongs to the human and is pinned to the bottom of the screen, so the renderer
    /// needs no rotation and "back" always means "toward my goal".
    func testHumanGoalIsAtTheBottom() {
        let arena = ArenaGeometry(tuning: tuning)
        XCTAssertEqual(arena.bearings[0], -Double.pi / 2, accuracy: 1e-12)
    }

    func testMouthWidthMatchesTheRequestedChord() {
        let arena = ArenaGeometry(tuning: tuning)
        let posts = arena.posts(of: 0)
        XCTAssertEqual(posts.left.distance(to: posts.right), tuning.goalMouthChord, accuracy: 1e-9)
    }

    func testMouthSpansDoNotOverlapAndLeaveMostlyWall() {
        let arena = ArenaGeometry(tuning: tuning)
        let spacing = Angles.tau / Double(arena.goalCount)
        XCTAssertLessThan(2 * arena.mouthHalfAngle, spacing)

        // Each goal is about 27° of the circle and the five together are about 37% of it, so
        // the pitch is still mostly wall — less so than it was, which is what pulled match
        // length back into the target band once scoring started wiping marks off tallies.
        let totalMouthArc = Double(arena.goalCount) * 2 * arena.mouthHalfAngle
        XCTAssertLessThan(totalMouthArc / Angles.tau, 0.45, "the pitch must stay mostly wall")
        XCTAssertGreaterThan(totalMouthArc / Angles.tau, 0.25, "and the goals worth defending")
    }

    func testBearingsResolveToTheRightGoalOrToWall() {
        let arena = ArenaGeometry(tuning: tuning)
        for goal in 0..<arena.goalCount {
            let centre = arena.bearings[goal]
            XCTAssertEqual(arena.openGoal(atBearing: centre), goal)
            // Just inside each post.
            XCTAssertEqual(arena.openGoal(atBearing: centre + arena.mouthHalfAngle * 0.99), goal)
            XCTAssertEqual(arena.openGoal(atBearing: centre - arena.mouthHalfAngle * 0.99), goal)
            // Just outside is wall.
            XCTAssertNil(arena.openGoal(atBearing: centre + arena.mouthHalfAngle * 1.01))
            XCTAssertTrue(arena.isWall(atBearing: centre + arena.mouthHalfAngle * 1.01))
        }
    }

    /// The seam at ±π falls between two goals; it must still read as ordinary wall.
    func testTheAngleSeamIsHandled() {
        let arena = ArenaGeometry(tuning: tuning)
        XCTAssertEqual(arena.openGoal(atBearing: .pi), arena.openGoal(atBearing: -.pi))
    }

    func testSealingTurnsAMouthIntoWall() {
        var arena = ArenaGeometry(tuning: tuning)
        let centre = arena.bearings[2]
        XCTAssertEqual(arena.openGoal(atBearing: centre), 2)

        arena.seal(2)

        XCTAssertNil(arena.openGoal(atBearing: centre))
        XCTAssertTrue(arena.isWall(atBearing: centre))
        // Every other goal is untouched — sealing does not move or resize anything.
        for goal in [0, 1, 3, 4] {
            XCTAssertEqual(arena.openGoal(atBearing: arena.bearings[goal]), goal)
        }
    }

    func testSealingRemovesThatGoalsPosts() {
        var arena = ArenaGeometry(tuning: tuning)
        XCTAssertEqual(arena.activePosts.count, 10)

        arena.seal(3)
        XCTAssertEqual(arena.activePosts.count, 8)

        let gone = arena.posts(of: 3)
        for post in arena.activePosts {
            XCTAssertGreaterThan(post.distance(to: gone.left), 1e-6)
            XCTAssertGreaterThan(post.distance(to: gone.right), 1e-6)
        }
    }

    func testPostsSitOnTheLine() {
        let arena = ArenaGeometry(tuning: tuning)
        for post in arena.activePosts {
            XCTAssertEqual(post.length, arena.radius, accuracy: 1e-9)
        }
    }

    func testHomeSpotIsInFrontOfYourOwnGoal() {
        let arena = ArenaGeometry(tuning: tuning)
        for goal in 0..<arena.goalCount {
            let home = arena.homeSpot(of: goal, fraction: tuning.homeSpotFraction)
            XCTAssertEqual(home.length, arena.radius * tuning.homeSpotFraction, accuracy: 1e-9)
            XCTAssertEqual(Angles.separation(home.angle, arena.bearings[goal]), 0, accuracy: 1e-9)
        }
    }

    func testAimBearingPointsAtTheMouth() {
        let arena = ArenaGeometry(tuning: tuning)
        let bearing = arena.aimBearing(from: .zero, at: 1)
        XCTAssertEqual(Angles.separation(bearing, arena.bearings[1]), 0, accuracy: 1e-9)
    }
}
