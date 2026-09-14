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

    /// True on the step the shot is taken.
    var kickReleased: Bool = false

    /// Power for this shot, `0...1`, bypassing whatever charge has accumulated.
    ///
    /// The thumbs use this: shooting is a tap, so there is no charge to read. Bots leave it
    /// nil and keep varying power by range, which is a thing they can judge and a thumb
    /// cannot.
    var kickPower: Double?

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

    /// The same input with the stick pushed only `fraction` of the way to the rim.
    ///
    /// Bots steer by pointing a unit vector at where they want to be, which is a stick held
    /// hard against the rim for the whole match. This is how `BotDifficulty.pace` is applied,
    /// and it is deliberately the *only* way it can be: the heading is untouched, so it
    /// changes how fast a bot runs and nothing else.
    func paced(by fraction: Double) -> PlayerInput {
        var copy = self
        copy.move = move * max(0, min(1, fraction))
        return copy
    }

    static func running(_ direction: Vec2) -> PlayerInput {
        PlayerInput(move: direction)
    }
}
