import Foundation

/// The handful of things that separate a hard bot from an easy one.
///
/// No tier gets extra speed, extra power, or knowledge a human could not have — those would be
/// unexpressible anyway, since a bot's sole output is the same `PlayerInput` a thumb produces.
/// What changes is how quickly it notices, how straight it shoots, how readily it commits to a
/// lunge, and how good a chance it holds out for before shooting. See `docs/GAME_DESIGN.md` §8.
///
/// A struct rather than an enum so the balance harness can build hybrids — "hard reactions,
/// easy dash appetite" — and find out which knob is actually responsible for an effect. That
/// is how the inverted difficulty was tracked down.
struct BotDifficulty: Equatable, Identifiable {

    let id: String
    let title: String

    /// How long a decision is held before the bot looks up and reconsiders. Steering toward
    /// the held target continues every step — this is thinking time, not paralysis.
    let reactionLatency: Double

    /// Standard deviation of aim error, in radians.
    let aimSigma: Double

    /// How willing the bot is to spend a dash on a block or a charge.
    let dashAppetite: Double

    /// How far the bot pushes the stick, `0...1`.
    ///
    /// Below 1 for every tier, which is a handicap rather than a hidden advantage and is the
    /// reason it can live here at all: `PlayerInput.move` already means "how hard the stick is
    /// pushed", a half push already means a lower top speed, and a person holding the stick a
    /// touch short of the rim is exactly what this describes. Nothing new is expressible.
    ///
    /// It exists because five players who all run flat out, all the time, read as a machine
    /// rather than as opponents — and because the person holding the phone should be the
    /// fastest thing on the pitch when they want to be.
    ///
    /// The same for every tier, deliberately. It was briefly a difficulty axis — 0.88 for
    /// easy up to 0.97 for hard — and that turned out to be the wrong knob twice over. A
    /// slower bot defends as badly as it attacks, so the tiers barely separated; and because
    /// slow play spreads the goals evenly, an all-easy match stopped being able to knock
    /// anybody out at all: eight of eighty never reached a winner inside fifteen minutes.
    /// Difficulty is how quickly a bot notices, how straight it shoots, how readily it
    /// commits, and how good a chance it holds out for. It is not how fast it runs.
    let pace: Double

    /// How good a look the bot holds out for before shooting, on `ShotEvaluator`'s scale.
    ///
    /// The scale is roughly: 0.4 is a long shot at a guarded mouth, 0.8 a decent look, and
    /// anything past 1.2 an invitation. Without a bar of any kind a bot took the best shot
    /// available even when the best available was terrible, which is why every restart ended
    /// with the ball being launched from the centre spot at the first mouth it saw.
    let shotBar: Double

    /// How long it will carry the ball looking for one before taking whatever is on.
    ///
    /// The escape valve for the bar. Without it a bot holding out for a look that never comes
    /// would simply stand on the ball until the stagnation rule fired.
    let carryPatience: Double

    static let easy = BotDifficulty(id: "easy", title: "Easy",
                                    reactionLatency: 0.150,
                                    aimSigma: 9 * .pi / 180,
                                    dashAppetite: 0.15,
                                    pace: 0.93,
                                    shotBar: 0.55,
                                    carryPatience: 1.2)

    static let normal = BotDifficulty(id: "normal", title: "Normal",
                                      reactionLatency: 0.090,
                                      aimSigma: 5 * .pi / 180,
                                      dashAppetite: 0.30,
                                      pace: 0.93,
                                      shotBar: 0.75,
                                      carryPatience: 1.8)

    static let hard = BotDifficulty(id: "hard", title: "Hard",
                                    reactionLatency: 0.045,
                                    aimSigma: 2.5 * .pi / 180,
                                    dashAppetite: 0.45,
                                    pace: 0.93,
                                    shotBar: 0.95,
                                    carryPatience: 2.4)

    static let all: [BotDifficulty] = [.easy, .normal, .hard]

    static func named(_ id: String) -> BotDifficulty {
        all.first { $0.id == id } ?? .normal
    }

    /// A copy with one knob replaced, for balance experiments.
    func with(reactionLatency: Double? = nil,
              aimSigma: Double? = nil,
              dashAppetite: Double? = nil,
              pace: Double? = nil,
              shotBar: Double? = nil,
              carryPatience: Double? = nil) -> BotDifficulty {
        BotDifficulty(id: id, title: title,
                      reactionLatency: reactionLatency ?? self.reactionLatency,
                      aimSigma: aimSigma ?? self.aimSigma,
                      dashAppetite: dashAppetite ?? self.dashAppetite,
                      pace: pace ?? self.pace,
                      shotBar: shotBar ?? self.shotBar,
                      carryPatience: carryPatience ?? self.carryPatience)
    }
}
