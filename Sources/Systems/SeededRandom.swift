import Foundation

/// SplitMix64. A value type on purpose: copying the generator copies the stream, so a bot can
/// be handed its own independent, reproducible source without any shared mutable state.
///
/// The system generator is never used anywhere in `Systems/` or `AI/` — determinism is what
/// makes the balance harness meaningful, and one stray `Double.random(in:)` would silently
/// destroy it.
struct SeededRandom: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        // Zero is a legitimate seed to pass but a poor SplitMix state, so it is offset.
        self.state = seed &+ 0x9E37_79B9_7F4A_7C15
    }

    mutating func next() -> UInt64 {
        state = state &+ 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// Uniform in `[0, 1)`. Uses the top 53 bits, which are the well-mixed ones.
    mutating func unit() -> Double {
        Double(next() >> 11) * (1.0 / 9_007_199_254_740_992.0)
    }

    mutating func double(in range: ClosedRange<Double>) -> Double {
        range.lowerBound + unit() * (range.upperBound - range.lowerBound)
    }

    mutating func int(in range: ClosedRange<Int>) -> Int {
        let span = UInt64(range.upperBound - range.lowerBound + 1)
        return range.lowerBound + Int(next() % span)
    }

    mutating func bool(chance: Double) -> Bool {
        unit() < chance
    }

    /// Normally distributed with the given standard deviation, via Box–Muller. Bot aim error
    /// is gaussian rather than uniform so that most shots are nearly right and the occasional
    /// one is badly wrong, which is how human error actually looks.
    mutating func gaussian(sigma: Double) -> Double {
        let u1 = max(unit(), 1e-12)
        let u2 = unit()
        return sigma * (-2 * log(u1)).squareRoot() * cos(Angles.tau * u2)
    }

    mutating func pick<T>(_ elements: [T]) -> T {
        elements[int(in: 0...(elements.count - 1))]
    }

    /// Fisher–Yates, so a shuffle is reproducible from the seed.
    mutating func shuffled<T>(_ elements: [T]) -> [T] {
        var result = elements
        guard result.count > 1 else { return result }
        for i in stride(from: result.count - 1, to: 0, by: -1) {
            result.swapAt(i, int(in: 0...i))
        }
        return result
    }
}
