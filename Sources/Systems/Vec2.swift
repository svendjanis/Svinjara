import Foundation

/// A 2D vector in simulation space: metres, x to the right, y up, origin at the centre spot.
///
/// The simulation is written against this rather than `CGPoint`/`CGVector` so that nothing in
/// `Systems/` or `AI/` has to import a graphics framework — see `docs/ARCHITECTURE.md` §2.
struct Vec2: Equatable, Hashable {
    var x: Double
    var y: Double

    static let zero = Vec2(x: 0, y: 0)

    init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }

    /// A vector of `length` pointing along `angle` radians. Bearings in this game are angles,
    /// so most construction goes through here.
    init(angle: Double, length: Double = 1) {
        self.x = cos(angle) * length
        self.y = sin(angle) * length
    }

    var lengthSquared: Double { x * x + y * y }
    var length: Double { (x * x + y * y).squareRoot() }

    /// Bearing in radians, in `(-π, π]`.
    var angle: Double { atan2(y, x) }

    /// Zero for a zero vector rather than NaN. Steering code normalises input that is very
    /// often exactly zero (thumb off the stick), and a NaN there would poison the whole state.
    var normalized: Vec2 {
        let len = length
        guard len > 1e-12 else { return .zero }
        return Vec2(x: x / len, y: y / len)
    }

    /// Rotated 90° counter-clockwise. The tangent to the circle at this bearing.
    var perpendicular: Vec2 { Vec2(x: -y, y: x) }

    func dot(_ other: Vec2) -> Double { x * other.x + y * other.y }

    /// The z component of the 3D cross product. Its sign says which side `other` lies on.
    func cross(_ other: Vec2) -> Double { x * other.y - y * other.x }

    func rotated(by radians: Double) -> Vec2 {
        let c = cos(radians), s = sin(radians)
        return Vec2(x: x * c - y * s, y: x * s + y * c)
    }

    /// Shortened to `maxLength` if longer, otherwise unchanged.
    func limited(to maxLength: Double) -> Vec2 {
        let lenSq = lengthSquared
        guard lenSq > maxLength * maxLength, lenSq > 1e-24 else { return self }
        return self * (maxLength / lenSq.squareRoot())
    }

    func distance(to other: Vec2) -> Double { (self - other).length }
    func distanceSquared(to other: Vec2) -> Double { (self - other).lengthSquared }

    static func + (a: Vec2, b: Vec2) -> Vec2 { Vec2(x: a.x + b.x, y: a.y + b.y) }
    static func - (a: Vec2, b: Vec2) -> Vec2 { Vec2(x: a.x - b.x, y: a.y - b.y) }
    static func * (v: Vec2, s: Double) -> Vec2 { Vec2(x: v.x * s, y: v.y * s) }
    static func * (s: Double, v: Vec2) -> Vec2 { v * s }
    static func / (v: Vec2, s: Double) -> Vec2 { Vec2(x: v.x / s, y: v.y / s) }
    static prefix func - (v: Vec2) -> Vec2 { Vec2(x: -v.x, y: -v.y) }
    static func += (a: inout Vec2, b: Vec2) { a = a + b }
    static func -= (a: inout Vec2, b: Vec2) { a = a - b }
    static func *= (v: inout Vec2, s: Double) { v = v * s }
}

/// Angle arithmetic. Bearings wrap, so comparing them with `<` or subtracting them naively is
/// wrong at the ±π seam — which is exactly where one of the five goals sits.
enum Angles {

    static let tau = 2 * Double.pi

    /// Folds any angle into `(-π, π]`.
    static func normalize(_ angle: Double) -> Double {
        var a = angle.truncatingRemainder(dividingBy: tau)
        if a <= -.pi { a += tau }
        if a > .pi { a -= tau }
        return a
    }

    /// The shortest signed rotation that takes `from` to `to`, in `(-π, π]`.
    static func delta(from: Double, to: Double) -> Double {
        normalize(to - from)
    }

    /// The unsigned angle between two bearings, in `[0, π]`.
    static func separation(_ a: Double, _ b: Double) -> Double {
        abs(delta(from: a, to: b))
    }

    /// `from` rotated toward `to` by at most `maxStep`. Used for turn-rate limiting.
    static func step(from: Double, to: Double, maxStep: Double) -> Double {
        let d = delta(from: from, to: to)
        guard abs(d) > maxStep else { return normalize(to) }
        return normalize(from + (d < 0 ? -maxStep : maxStep))
    }
}
