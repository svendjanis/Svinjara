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

    /// True on the step a tackle is asked for.
    var dashRequested: Bool = false

    /// Ask for the shot to be snapped onto a nearby open mouth.
    ///
    /// This is why it lives in the input struct rather than in the rules: aiming to the degree
    /// is something a bot can do and a thumb cannot, so the aid belongs to whoever is holding
    /// the phone. Both still travel the same single code path into the engine — a bot is free
    /// to ask for it and simply has no reason to.
    var aimAssist: Bool = false

    static let idle = PlayerInput()

    static func running(_ direction: Vec2) -> PlayerInput {
        PlayerInput(move: direction)
    }
}
