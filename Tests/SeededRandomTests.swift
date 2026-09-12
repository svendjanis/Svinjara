import XCTest
@testable import Svinjara

final class SeededRandomTests: XCTestCase {

    /// The property the whole balance harness rests on.
    func testSameSeedGivesSameSequence() {
        var a = SeededRandom(seed: 12345)
        var b = SeededRandom(seed: 12345)
        for _ in 0..<10_000 {
            XCTAssertEqual(a.next(), b.next())
        }
    }

    func testDifferentSeedsDiverge() {
        var a = SeededRandom(seed: 1)
        var b = SeededRandom(seed: 2)
        let first = (0..<64).map { _ in a.next() }
        let second = (0..<64).map { _ in b.next() }
        XCTAssertNotEqual(first, second)
    }

    /// It is a value type on purpose: copying the generator copies the stream, so handing a
    /// bot its own source cannot perturb anyone else's.
    func testCopyingCopiesTheStream() {
        var original = SeededRandom(seed: 99)
        _ = original.next()
        var copy = original
        XCTAssertEqual(original.next(), copy.next())
        XCTAssertEqual(original.next(), copy.next())
    }

    func testUnitStaysInRange() {
        var rng = SeededRandom(seed: 7)
        for _ in 0..<50_000 {
            let value = rng.unit()
            XCTAssertGreaterThanOrEqual(value, 0)
            XCTAssertLessThan(value, 1)
        }
    }

    func testUnitIsRoughlyUniform() {
        var rng = SeededRandom(seed: 4242)
        var buckets = [Int](repeating: 0, count: 10)
        let draws = 100_000
        for _ in 0..<draws { buckets[min(9, Int(rng.unit() * 10))] += 1 }
        // Each bucket should hold about a tenth; 15% slack is far outside plausible noise at
        // this sample size but would still catch a genuinely broken generator.
        for count in buckets {
            XCTAssertGreaterThan(count, draws / 10 - draws / 10 * 15 / 100)
            XCTAssertLessThan(count, draws / 10 + draws / 10 * 15 / 100)
        }
    }

    func testIntStaysInRange() {
        var rng = SeededRandom(seed: 11)
        var seen = Set<Int>()
        for _ in 0..<5_000 {
            let value = rng.int(in: 3...7)
            XCTAssertTrue((3...7).contains(value))
            seen.insert(value)
        }
        XCTAssertEqual(seen, [3, 4, 5, 6, 7])
    }

    func testGaussianHasTheRequestedSpread() {
        var rng = SeededRandom(seed: 2024)
        let sigma = 0.4
        var sum = 0.0, sumSquares = 0.0
        let draws = 100_000
        for _ in 0..<draws {
            let value = rng.gaussian(sigma: sigma)
            sum += value
            sumSquares += value * value
        }
        let mean = sum / Double(draws)
        let deviation = (sumSquares / Double(draws) - mean * mean).squareRoot()
        XCTAssertEqual(mean, 0, accuracy: 0.02)
        XCTAssertEqual(deviation, sigma, accuracy: 0.02)
    }

    func testShuffleIsAPermutationAndReproducible() {
        let input = Array(0..<50)
        var a = SeededRandom(seed: 5)
        var b = SeededRandom(seed: 5)
        let first = a.shuffled(input)
        XCTAssertEqual(first.sorted(), input)
        XCTAssertEqual(first, b.shuffled(input))
        XCTAssertNotEqual(first, input)
    }
}
