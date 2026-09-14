import Foundation

/// Every number the simulation reads. Documented in `docs/PHYSICS_AND_TUNING.md` — if a value
/// moves here, that table moves with it.
///
/// A struct with defaults rather than a `static let` wall, so a balance test can build a
/// variant and run a few hundred matches against it without touching global state.
struct Tuning: Equatable {

    // MARK: Step

    /// The simulation always advances in slices of exactly this length. The renderer
    /// accumulates real frame time and calls `step` a whole number of times; it never passes
    /// a frame duration in, because then the result would depend on the display refresh rate.
    var fixedStep: Double = 1.0 / 120.0

    // MARK: Arena

    var pitchRadius: Double = 9.5
    /// Straight-line width of a goal mouth. Converted to an angular span by `ArenaGeometry`.
    var goalMouthChord: Double = 4.4
    var postRadius: Double = 0.12
    var goalCount: Int = 5

    // MARK: Ball

    var ballRadius: Double = 0.11
    /// Rolling resistance, as exponential decay per second. Concrete is fast — grass would be
    /// nearer 1.4, and the ball would die in midfield instead of rattling around the circle.
    ///
    /// Raised a little along with the general slowdown: a ball that keeps running after
    /// everyone else has slowed down is a ball nobody can settle on, and settling on it is the
    /// whole game. Only a little, though — a full-power shot still has to be able to cross the
    /// pitch, and `kickMaxSpeed / ballDamping` is what says whether it can. At 0.80 it could
    /// not, and a game where the far goal is out of range is a game with two fewer targets.
    var ballDamping: Double = 0.72
    var wallRestitution: Double = 0.72
    var postRestitution: Double = 0.85
    /// Below this the ball is simply stopped, so it never creeps for ever at 0.001 m/s.
    var ballRestThreshold: Double = 0.15
    var ballMaxSpeed: Double = 19.0

    // MARK: Player

    var playerRadius: Double = 0.42

    /// Acceleration and top speed are separate on purpose, and only the ceiling came down in
    /// the slowdown.
    ///
    /// The circle is 19 m across. At 5.6 m/s a player crossed the whole of it in 3.4 seconds,
    /// which left no time to read where the ball was going to end up — it was a scramble
    /// rather than a game. At 4.5 it takes 4.2 s. Acceleration was cut in the same proportion
    /// so the time from standstill to top speed is unchanged at ~0.21 s: the game is slower,
    /// but the stick answers exactly as fast as it did.
    var playerAcceleration: Double = 21.0
    var playerTopSpeed: Double = 4.5
    /// Applied only when there is no steering input — see `PlayerPhysics.integrate`.
    var playerFriction: Double = 8.0
    var playerTurnRate: Double = 12.0
    var playerRestitution: Double = 0.30

    // MARK: Kick

    var kickChargeTime: Double = 0.55
    /// A bare tap still has to feel like a shot, not a nudge.
    var kickMinSpeed: Double = 7.5
    var kickMaxSpeed: Double = 15.0
    /// Added to the two radii to give the distance at which the ball is "at your feet".
    var kickReachPadding: Double = 0.50
    /// Generous, because a thumb steers the facing and a person cannot hold a heading to the
    /// degree while also being barged by four other people.
    var kickArc: Double = 75 * .pi / 180

    /// How far off a goal mouth a shot may be and still be snapped onto it.
    ///
    /// A thumb on a joystick cannot aim to the degree, and without this the only way to line a
    /// goal up is to run at it — which means chasing the ball toward the target rather than
    /// choosing one. Requested per-input, so it is an aid to the thumbs rather than a change
    /// to the rules.
    var aimAssistAngle: Double = 40 * .pi / 180

    /// The fraction of your closing speed the ball takes when you run into it.
    ///
    /// Under 1 on purpose: at 1 the ball leaves at exactly your speed and runs away from you
    /// for as long as it takes rolling resistance to bring it back, which is what made
    /// carrying it feel like herding. Below 1 it always settles back at your feet.
    var dribbleGrip: Double = 0.72

    /// How far the push from a body contact may be steered toward the way the player is
    /// actually running, in radians.
    ///
    /// A circle pushes the ball off along the line between the two centres, so a touch taken
    /// half a step off-line sends the ball sideways — and because that leaves it further off
    /// line, the next touch sends it further still. Contact alone diverges, which is the
    /// honest reason carrying the ball felt like herding even after the grip was fixed.
    ///
    /// A foot is not a circle: it points where its owner is going. Steering the push toward
    /// the direction of travel makes successive touches converge on "in front of me", which
    /// is what dribbling is. Capped rather than absolute, so running past a ball still only
    /// brushes it — you cannot drag it round a corner it never went near.
    var dribbleGather: Double = 0.55

    // MARK: Dash

    /// Slowed with everything else, and lengthened to match, so a lunge still covers the same
    /// ~2.1 m of ground it always did.
    var dashDuration: Double = 0.27
    var dashSpeed: Double = 7.7
    var dashCooldown: Double = 1.6
    var dashShoveImpulse: Double = 4.5
    var staggerDuration: Double = 0.4
    /// How much steering authority a staggered player keeps.
    var staggerControl: Double = 0.35

    // MARK: Match

    /// How many you may let in before you walk home.
    ///
    /// Six, until the bots learned to defend. Elimination needs somebody to *fall behind*,
    /// and redemption means a goal only grows the table when its scorer is already on zero.
    /// That was fine against bots that conceded in lumps — a restart used to hand somebody
    /// three in a minute. Once pressing and a restart that is not a free shot spread the
    /// goals evenly, the table stopped growing: measured over 80 easy matches, 4.4 goals a
    /// minute were being scored while the total tally climbed by 1.3, so reaching six took
    /// thirteen minutes and one match in ten never got there inside fifteen.
    ///
    /// The number is the cheap half of that trade. Turning redemption off entirely puts six
    /// back in the band at a 239 s median — it is that rule, not the pace, that costs the
    /// time — but redemption is what stops camping on your own line being the winning move,
    /// so the threshold gives way instead. At four the median match is 284 s and the longest
    /// of 240 measured was 471 s, which is the three-to-five minutes the game is designed
    /// around. See `docs/PHYSICS_AND_TUNING.md` §7.
    var concedesToElimination: Int = 4

    /// Scoring takes one back off your own tally, floored at zero.
    ///
    /// This exists because the game as first specified had a dominant strategy: sit on your own
    /// line and wait. Only conceding counts, so every goal you score helps all four rivals
    /// equally while your own mouth is unguarded — measured over 150 bot matches, the tier that
    /// attacked 37% of the time finished 3.42nd on average and the tier that attacked 21%
    /// finished 2.63rd. Being able to claw one back is what makes going forward worth the risk.
    ///
    /// The floor at zero is load-bearing, not a detail. Without it every goal moves exactly one
    /// mark from the scorer to the conceder, the total across all five players never grows, and
    /// nobody is ever eliminated.
    var redemptionForScoring: Bool = true
    var celebrationDuration: Double = 1.2

    /// If the ball has not travelled `stagnationRadius` from where it was `stagnationTimeout`
    /// ago, it is returned to the centre spot. See `docs/RULES.md` §10.
    var stagnationTimeout: Double = 7.0
    var stagnationRadius: Double = 2.0

    /// Where a goal kick is placed, as a fraction of the pitch radius.
    ///
    /// See `MatchState.restartTaker` for why the player who conceded restarts play at all.
    /// 0.78 puts the ball about 2.1 m in front of their own line — clear of their own posts,
    /// and about 10 m from the nearest rival mouth, which is what makes a goal straight from
    /// a restart geometrically uninteresting rather than merely unlikely.
    var goalKickFraction: Double = 0.78

    /// How far off their line a player may be nudged at a restart, as a fraction of the pitch
    /// radius. See `MatchEngine.resetForKickoff` — this is what stops every restart being the
    /// same restart. Sideways spread is the width of the player's own mouth, so it is always
    /// their own goal they are stood in front of.
    var kickoffSpread: Double = 0.06
    /// Home spot distance from the centre, as a fraction of the pitch radius.
    ///
    /// Deep on purpose. At 0.55 everyone stood 4.3 m *in front of* their own mouth, which left
    /// all five goals undefended at the instant of every kickoff — whoever won the race to the
    /// centre had a free shot at any of them, and 19% of all goals arrived within two seconds
    /// of a restart. Starting on your own line means a restart begins with the goals guarded,
    /// which is what a restart should look like.
    var homeSpotFraction: Double = 0.88

    static let `default` = Tuning()

    // MARK: Derived

    /// Time to go from standstill to top speed under full input. ~0.22 s.
    var timeToTopSpeed: Double { playerTopSpeed / playerAcceleration }

    /// Time for a player at top speed to decay to 1% of it with no input. ~0.58 s.
    var timeToStop: Double { log(100) / playerFriction }

    /// How close the ball must be to be kickable.
    var kickReach: Double { playerRadius + ballRadius + kickReachPadding }

    /// Distance covered by one dash. ~2.1 m — enough to reach a shot at the far post of your
    /// own mouth, not enough to cross the pitch with.
    var dashDistance: Double { dashSpeed * dashDuration }
}
