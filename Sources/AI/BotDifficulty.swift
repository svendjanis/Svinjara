import Foundation

/// The only three things that separate a hard bot from an easy one.
///
/// No tier gets extra speed, extra power, or knowledge a human could not have — those would be
/// unexpressible anyway, since a bot's sole output is the same `PlayerInput` a thumb produces.
/// What changes is how quickly it notices, how straight it shoots, and how readily it commits
/// to a lunge. See `docs/GAME_DESIGN.md` §8.
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

    static let easy = BotDifficulty(id: "easy", title: "Easy",
                                    reactionLatency: 0.150,
                                    aimSigma: 9 * .pi / 180,
                                    dashAppetite: 0.15)

    static let normal = BotDifficulty(id: "normal", title: "Normal",
                                      reactionLatency: 0.090,
                                      aimSigma: 5 * .pi / 180,
                                      dashAppetite: 0.30)

    static let hard = BotDifficulty(id: "hard", title: "Hard",
                                    reactionLatency: 0.045,
                                    aimSigma: 2.5 * .pi / 180,
                                    dashAppetite: 0.45)

    static let all: [BotDifficulty] = [.easy, .normal, .hard]

    static func named(_ id: String) -> BotDifficulty {
        all.first { $0.id == id } ?? .normal
    }

    /// A copy with one knob replaced, for balance experiments.
    func with(reactionLatency: Double? = nil,
              aimSigma: Double? = nil,
              dashAppetite: Double? = nil) -> BotDifficulty {
        BotDifficulty(id: id, title: title,
                      reactionLatency: reactionLatency ?? self.reactionLatency,
                      aimSigma: aimSigma ?? self.aimSigma,
                      dashAppetite: dashAppetite ?? self.dashAppetite)
    }
}
