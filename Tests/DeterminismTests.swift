import XCTest
@testable import Svinjara

/// Story D5. Balance work over hundreds of simulated matches is only meaningful if the same
/// inputs give the same match every time, so this is load-bearing rather than decorative.
final class DeterminismTests: XCTestCase {

    private let tuning = Tuning.default

    /// A fixed, reproducible script of thumb movements for all five players.
    private func script(seed: UInt64, steps: Int) -> [[PlayerInput]] {
        var rng = SeededRandom(seed: seed)
        var frames: [[PlayerInput]] = []
        var heldDirection = [Vec2](repeating: .zero, count: 5)

        for step in 0..<steps {
            if step % 25 == 0 {
                for index in 0..<5 {
                    heldDirection[index] = Vec2(angle: rng.double(in: -.pi ... .pi),
                                                length: rng.double(in: 0.4...1))
                }
            }
            frames.append((0..<5).map { index in
                PlayerInput(move: heldDirection[index],
                            kickHeld: rng.bool(chance: 0.5),
                            kickReleased: rng.bool(chance: 0.12),
                            dashRequested: rng.bool(chance: 0.03))
            })
        }
        return frames
    }

    private func play(_ frames: [[PlayerInput]]) -> MatchState {
        var engine = MatchFixture.engine(tuning: tuning)
        for frame in frames where !engine.state.isOver {
            engine.step(inputs: frame)
        }
        return engine.state
    }

    func testTheSameScriptProducesTheSameMatch() {
        let frames = script(seed: 20260912, steps: 20_000)
        let first = play(frames)
        let second = play(frames)

        XCTAssertEqual(first, second)
        // Positions compared as exact doubles, not within a tolerance — any drift at all is
        // a determinism bug, however small.
        for index in 0..<5 {
            XCTAssertEqual(first.players[index].body.position.x,
                           second.players[index].body.position.x)
            XCTAssertEqual(first.players[index].body.position.y,
                           second.players[index].body.position.y)
        }
        XCTAssertEqual(first.ball.position.x, second.ball.position.x)
        XCTAssertEqual(first.ball.position.y, second.ball.position.y)
    }

    func testTwoDifferentScriptsDiverge() {
        XCTAssertNotEqual(play(script(seed: 1, steps: 4_000)),
                          play(script(seed: 2, steps: 4_000)))
    }

    /// A replay that is fed the script one step at a time must match one fed it in bulk —
    /// proving the engine carries no hidden state between calls.
    func testSteppingIsStateless() {
        let frames = script(seed: 777, steps: 6_000)

        var bulk = MatchFixture.engine(tuning: tuning)
        for frame in frames where !bulk.state.isOver { bulk.step(inputs: frame) }

        var piecewise = MatchFixture.engine(tuning: tuning)
        for frame in frames where !piecewise.state.isOver {
            var copy = piecewise
            copy.step(inputs: frame)
            piecewise = copy
        }
        XCTAssertEqual(bulk.state, piecewise.state)
    }

    func testABotMatchRunsToTheSameWinnerEveryTime() {
        let results = (0..<3).map { _ in BotMatch.play(seed: 21, capSeconds: 900) }
        XCTAssertNotNil(results[0].winner)
        XCTAssertEqual(Set(results.map(\.winner)).count, 1,
                       "same seed, same winner: \(results.map(\.winner))")
        XCTAssertEqual(Set(results.map(\.seconds)).count, 1)
    }
}
