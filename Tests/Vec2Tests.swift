import XCTest
@testable import Svinjara

final class Vec2Tests: XCTestCase {

    private let accuracy = 1e-12

    func testArithmetic() {
        let a = Vec2(x: 3, y: 4)
        let b = Vec2(x: -1, y: 2)

        XCTAssertEqual(a + b, Vec2(x: 2, y: 6))
        XCTAssertEqual(a - b, Vec2(x: 4, y: 2))
        XCTAssertEqual(a * 2, Vec2(x: 6, y: 8))
        XCTAssertEqual(2 * a, Vec2(x: 6, y: 8))
        XCTAssertEqual(a / 2, Vec2(x: 1.5, y: 2))
        XCTAssertEqual(-a, Vec2(x: -3, y: -4))
    }

    func testLengthAndDistance() {
        XCTAssertEqual(Vec2(x: 3, y: 4).length, 5, accuracy: accuracy)
        XCTAssertEqual(Vec2(x: 3, y: 4).lengthSquared, 25, accuracy: accuracy)
        XCTAssertEqual(Vec2(x: 1, y: 1).distance(to: Vec2(x: 4, y: 5)), 5, accuracy: accuracy)
    }

    func testDotAndCross() {
        XCTAssertEqual(Vec2(x: 1, y: 0).dot(Vec2(x: 0, y: 1)), 0, accuracy: accuracy)
        XCTAssertEqual(Vec2(x: 2, y: 3).dot(Vec2(x: 4, y: 5)), 23, accuracy: accuracy)
        // Cross sign says which side the other vector lies on.
        XCTAssertGreaterThan(Vec2(x: 1, y: 0).cross(Vec2(x: 0, y: 1)), 0)
        XCTAssertLessThan(Vec2(x: 1, y: 0).cross(Vec2(x: 0, y: -1)), 0)
    }

    /// The whole reason `normalized` is not the obvious one-liner: steering input is very
    /// often exactly zero, and a NaN there would poison every position downstream.
    func testNormalizingZeroGivesZeroNotNaN() {
        let n = Vec2.zero.normalized
        XCTAssertEqual(n, .zero)
        XCTAssertFalse(n.x.isNaN)
        XCTAssertFalse(n.y.isNaN)
    }

    func testNormalizedHasUnitLength() {
        for angle in stride(from: -Double.pi, through: .pi, by: 0.37) {
            let v = Vec2(angle: angle, length: 7.3)
            XCTAssertEqual(v.normalized.length, 1, accuracy: 1e-12)
            // Compared as a bearing: -π and +π are the same direction, and one of the five
            // goals sits on exactly that seam.
            XCTAssertEqual(Angles.separation(v.normalized.angle, angle), 0, accuracy: 1e-12)
        }
    }

    func testAngleConstructionRoundTrips() {
        for angle in stride(from: -3.0, through: 3.0, by: 0.25) {
            let v = Vec2(angle: angle, length: 2)
            XCTAssertEqual(v.length, 2, accuracy: 1e-12)
            XCTAssertEqual(Angles.separation(v.angle, angle), 0, accuracy: 1e-12)
        }
    }

    func testRotation() {
        let v = Vec2(x: 1, y: 0)
        let turned = v.rotated(by: .pi / 2)
        XCTAssertEqual(turned.x, 0, accuracy: 1e-15)
        XCTAssertEqual(turned.y, 1, accuracy: 1e-15)
        // Rotation preserves length.
        XCTAssertEqual(Vec2(x: 3, y: -4).rotated(by: 1.1).length, 5, accuracy: 1e-12)
    }

    func testPerpendicularIsTangent() {
        let radial = Vec2(angle: 0.8, length: 11)
        XCTAssertEqual(radial.dot(radial.perpendicular), 0, accuracy: 1e-12)
    }

    func testLimitedOnlyShortens() {
        XCTAssertEqual(Vec2(x: 3, y: 4).limited(to: 10), Vec2(x: 3, y: 4))
        XCTAssertEqual(Vec2(x: 3, y: 4).limited(to: 5).length, 5, accuracy: 1e-12)
        XCTAssertEqual(Vec2(x: 30, y: 40).limited(to: 5).length, 5, accuracy: 1e-12)
        XCTAssertEqual(Vec2.zero.limited(to: 5), .zero)
    }
}

final class AnglesTests: XCTestCase {

    func testNormalizeFoldsIntoRange() {
        for raw in stride(from: -20.0, through: 20.0, by: 0.13) {
            let a = Angles.normalize(raw)
            XCTAssertGreaterThan(a, -Double.pi - 1e-12)
            XCTAssertLessThanOrEqual(a, Double.pi + 1e-12)
            // Same direction as the input.
            XCTAssertEqual(cos(a), cos(raw), accuracy: 1e-12)
            XCTAssertEqual(sin(a), sin(raw), accuracy: 1e-12)
        }
    }

    /// One of the five goals sits at the ±π seam, so naive subtraction of bearings is wrong
    /// exactly where it would matter most.
    func testDeltaTakesTheShortWayRoundTheSeam() {
        XCTAssertEqual(Angles.delta(from: 3.1, to: -3.1), 0.0831853, accuracy: 1e-6)
        XCTAssertEqual(Angles.delta(from: -3.1, to: 3.1), -0.0831853, accuracy: 1e-6)
        XCTAssertEqual(Angles.delta(from: 0, to: 1), 1, accuracy: 1e-12)
    }

    func testSeparationIsUnsigned() {
        XCTAssertEqual(Angles.separation(3.1, -3.1), 0.0831853, accuracy: 1e-6)
        XCTAssertEqual(Angles.separation(-3.1, 3.1), 0.0831853, accuracy: 1e-6)
        XCTAssertEqual(Angles.separation(0, .pi), .pi, accuracy: 1e-12)
    }

    func testStepIsRateLimitedAndArrivesExactly() {
        // Too far to reach in one step: moves by exactly the limit.
        XCTAssertEqual(Angles.step(from: 0, to: 2, maxStep: 0.5), 0.5, accuracy: 1e-12)
        XCTAssertEqual(Angles.step(from: 0, to: -2, maxStep: 0.5), -0.5, accuracy: 1e-12)
        // Within reach: snaps to the target rather than overshooting it.
        XCTAssertEqual(Angles.step(from: 0, to: 0.3, maxStep: 0.5), 0.3, accuracy: 1e-12)
        // Across the seam, the short way.
        XCTAssertEqual(Angles.step(from: 3.1, to: -3.1, maxStep: 0.5), -3.1, accuracy: 1e-6)
    }
}
