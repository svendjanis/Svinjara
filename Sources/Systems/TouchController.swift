import Foundation

/// Turns raw touches into a `PlayerInput`.
///
/// Deliberately free of UIKit and SpriteKit: the whole control scheme — the floating stick,
/// the charge, the tackle — is then testable without a scene and without a finger, which is
/// the only practical way to pin down behaviour like "a second thumb must not disturb the
/// first one".
struct TouchController {

    struct Layout {
        /// Distance from the stick's origin at which the thumb is at full tilt.
        var stickRadius: Double = 52
        /// Movement under this is treated as holding still, not as a very slow walk.
        var deadZone: Double = 7

        var shootCentre: Vec2 = .zero
        var shootRadius: Double = 40
        var tackleCentre: Vec2 = .zero
        var tackleRadius: Double = 32

        /// Buttons are hit-tested larger than they are drawn. A thumb does not land where its
        /// owner thinks it did, and missing the shot button is far worse than the odd
        /// generous hit.
        var touchSlop: Double = 1.35
    }

    /// Which control a touch grabbed. Decided once, on touch-down, and held for the life of
    /// that touch — a thumb that slides off the shoot button is still shooting.
    private enum Grabbed {
        case stick
        case shoot
        case tackle
    }

    var layout = Layout()

    /// Where the stick appeared and where the thumb is now, for the HUD to draw.
    private(set) var stickOrigin: Vec2?
    private(set) var stickPoint: Vec2?

    private var holders: [Int: Grabbed] = [:]
    private var pendingRelease = false
    private var pendingTackle = false

    var isShootDown: Bool { holders.values.contains(.shoot) }
    var isTackleDown: Bool { holders.values.contains(.tackle) }

    /// `0...1`, for drawing the stick knob.
    var stickOffset: Vec2 {
        guard let origin = stickOrigin, let point = stickPoint else { return .zero }
        return (point - origin).limited(to: layout.stickRadius)
    }

    // MARK: Touches

    mutating func touchDown(id: Int, at point: Vec2) {
        switch zone(at: point) {
        case .shoot:
            guard !isShootDown else { return }
            holders[id] = .shoot

        case .tackle:
            guard !isTackleDown else { return }
            holders[id] = .tackle
            pendingTackle = true

        case .stick:
            guard !holders.values.contains(.stick) else { return }
            holders[id] = .stick
            stickOrigin = point
            stickPoint = point
        }
    }

    mutating func touchMoved(id: Int, to point: Vec2) {
        guard holders[id] == .stick else { return }
        stickPoint = point
    }

    mutating func touchUp(id: Int) {
        guard let grabbed = holders.removeValue(forKey: id) else { return }
        switch grabbed {
        case .stick:
            stickOrigin = nil
            stickPoint = nil
        case .shoot:
            pendingRelease = true
        case .tackle:
            break
        }
    }

    mutating func cancelAll() {
        holders.removeAll()
        stickOrigin = nil
        stickPoint = nil
        pendingRelease = false
        pendingTackle = false
    }

    /// Buttons first, so a thumb landing on one is never mistaken for the stick.
    private func zone(at point: Vec2) -> Grabbed {
        if point.distance(to: layout.shootCentre) <= layout.shootRadius * layout.touchSlop {
            return .shoot
        }
        if point.distance(to: layout.tackleCentre) <= layout.tackleRadius * layout.touchSlop {
            return .tackle
        }
        return .stick
    }

    // MARK: Output

    /// The input for this step. One-shot flags are cleared, so a release or a tackle is
    /// delivered to exactly one simulation step however many frames the finger was down.
    mutating func consume() -> PlayerInput {
        let input = PlayerInput(move: move(),
                                kickHeld: isShootDown,
                                kickReleased: pendingRelease,
                                dashRequested: pendingTackle,
                                aimAssist: true)
        pendingRelease = false
        pendingTackle = false
        return input
    }

    private func move() -> Vec2 {
        guard let origin = stickOrigin, let point = stickPoint else { return .zero }
        let offset = point - origin
        let distance = offset.length
        guard distance > layout.deadZone else { return .zero }
        return offset.normalized * min(1, distance / layout.stickRadius)
    }
}
