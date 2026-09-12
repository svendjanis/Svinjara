import Foundation

/// Turns raw touches into a `PlayerInput`.
///
/// Deliberately free of UIKit and SpriteKit: the whole control scheme — the floating stick, the
/// charge, the double-tap lunge — is then testable without a scene and without a finger, which
/// is the only practical way to pin down behaviour like "a second thumb must not disturb the
/// first one".
struct TouchController {

    struct Layout {
        /// Distance from the stick's origin at which the thumb is at full tilt.
        var stickRadius: Double = 52
        /// Movement under this is treated as holding still, not as a very slow walk.
        var deadZone: Double = 7
        /// Two taps inside this window are a lunge rather than two kicks.
        var doubleTapWindow: Double = 0.26
    }

    var layout = Layout()

    /// Where the stick appeared and where the thumb is now, for the HUD to draw.
    private(set) var stickOrigin: Vec2?
    private(set) var stickPoint: Vec2?

    private var stickTouch: Int?
    private var kickTouch: Int?

    /// The current press is the second of a double tap, so it lunges and must not also kick.
    private var pressIsLunge = false
    private var lastKickReleasedAt: Double?

    private var pendingRelease = false
    private var pendingDash = false

    var isKickDown: Bool { kickTouch != nil }

    /// `0...1`, for drawing the stick knob.
    var stickOffset: Vec2 {
        guard let origin = stickOrigin, let point = stickPoint else { return .zero }
        return (point - origin).limited(to: layout.stickRadius)
    }

    // MARK: Touches

    mutating func touchDown(id: Int, at point: Vec2, onKickSide: Bool, now: Double) {
        if onKickSide {
            guard kickTouch == nil else { return }
            kickTouch = id
            if let last = lastKickReleasedAt, now - last <= layout.doubleTapWindow {
                pressIsLunge = true
                pendingDash = true
            } else {
                pressIsLunge = false
            }
        } else {
            guard stickTouch == nil else { return }
            stickTouch = id
            stickOrigin = point
            stickPoint = point
        }
    }

    mutating func touchMoved(id: Int, to point: Vec2) {
        guard id == stickTouch else { return }
        stickPoint = point
    }

    mutating func touchUp(id: Int, now: Double) {
        if id == stickTouch {
            stickTouch = nil
            stickOrigin = nil
            stickPoint = nil
            return
        }
        guard id == kickTouch else { return }
        kickTouch = nil
        // The second tap of a double tap has already been spent on the lunge; letting it also
        // kick would fire a shot nobody asked for every time you dived.
        if !pressIsLunge { pendingRelease = true }
        lastKickReleasedAt = now
        pressIsLunge = false
    }

    mutating func cancelAll() {
        stickTouch = nil
        stickOrigin = nil
        stickPoint = nil
        kickTouch = nil
        pressIsLunge = false
        pendingRelease = false
        pendingDash = false
    }

    // MARK: Output

    /// The input for this step. One-shot flags are cleared, so a release or a lunge is
    /// delivered to exactly one simulation step however many frames the finger was down.
    mutating func consume() -> PlayerInput {
        let input = PlayerInput(move: move(),
                                kickHeld: kickTouch != nil && !pressIsLunge,
                                kickReleased: pendingRelease,
                                dashRequested: pendingDash)
        pendingRelease = false
        pendingDash = false
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
