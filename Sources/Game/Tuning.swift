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
    var goalMouthChord: Double = 3.6
    var postRadius: Double = 0.12
    var goalCount: Int = 5

    // MARK: Ball

    var ballRadius: Double = 0.11
    /// Rolling resistance, as exponential decay per second. Concrete is fast — grass would be
    /// nearer 1.4, and the ball would die in midfield instead of rattling around the circle.
    var ballDamping: Double = 0.68
    var wallRestitution: Double = 0.72
    var postRestitution: Double = 0.85
    /// Below this the ball is simply stopped, so it never creeps for ever at 0.001 m/s.
    var ballRestThreshold: Double = 0.15
    var ballMaxSpeed: Double = 22.0

    // MARK: Player

    var playerRadius: Double = 0.42
    var playerAcceleration: Double = 26.0
    var playerTopSpeed: Double = 5.6
    /// Applied only when there is no steering input — see `PlayerPhysics.integrate`.
    var playerFriction: Double = 8.0
    var playerTurnRate: Double = 12.0
    var playerRestitution: Double = 0.30

    // MARK: Kick

    var kickChargeTime: Double = 0.55
    /// A bare tap still has to feel like a shot, not a nudge.
    var kickMinSpeed: Double = 8.5
    var kickMaxSpeed: Double = 17.0
    /// Added to the two radii to give the distance at which the ball is "at your feet".
    var kickReachPadding: Double = 0.35
    var kickArc: Double = 60 * .pi / 180

    /// How far off a goal mouth a shot may be and still be snapped onto it.
    ///
    /// A thumb on a joystick cannot aim to the degree, and without this the only way to line a
    /// goal up is to run at it — which means chasing the ball toward the target rather than
    /// choosing one. Requested per-input, so it is an aid to the thumbs rather than a change
    /// to the rules.
    var aimAssistAngle: Double = 25 * .pi / 180

    /// The fraction of your closing speed the ball takes when you run into it.
    ///
    /// Under 1 on purpose: at 1 the ball leaves at exactly your speed and runs away from you
    /// for as long as it takes rolling resistance to bring it back, which is what made
    /// carrying it feel like herding. Below 1 it always settles back at your feet.
    var dribbleGrip: Double = 0.78

    // MARK: Dash

    var dashDuration: Double = 0.22
    var dashSpeed: Double = 9.5
    var dashCooldown: Double = 1.6
    var dashShoveImpulse: Double = 4.5
    var staggerDuration: Double = 0.4
    /// How much steering authority a staggered player keeps.
    var staggerControl: Double = 0.35

    // MARK: Match

    var concedesToElimination: Int = 6
    var celebrationDuration: Double = 1.2

    /// If the ball has not travelled `stagnationRadius` from where it was `stagnationTimeout`
    /// ago, it is returned to the centre spot. See `docs/RULES.md` §10.
    var stagnationTimeout: Double = 7.0
    var stagnationRadius: Double = 2.0
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
