import Foundation

/// Everything a player can express in one step — and the *only* channel into the simulation.
///
/// The human's thumbs produce this, and so does `BotBrain`. A bot therefore cannot teleport,
/// out-run or out-kick a human, because none of those are expressible here. Fairness is a
/// property of the type rather than of anyone's restraint. See `docs/ARCHITECTURE.md` §5.
struct PlayerInput: Equatable {
    /// Desired heading. Magnitude `0...1`; a partly-pushed stick means a lower top speed.
    var move: Vec2 = .zero

    /// True for every step the kick button is down. The engine accumulates the charge.
    var kickHeld: Bool = false

    /// True on the single step the button came up.
    var kickReleased: Bool = false

    /// True on the step a lunge is asked for. Double-tap detection belongs to the input layer,
    /// not the engine — bots simply set this directly.
    var dashRequested: Bool = false

    static let idle = PlayerInput()

    static func running(_ direction: Vec2) -> PlayerInput {
        PlayerInput(move: direction)
    }
}
