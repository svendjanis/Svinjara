import Foundation

/// What became of the ball at the boundary this step.
enum BoundaryOutcome: Equatable {
    case none
    case hitPost
    case bounced
    case scored(goal: Int)
}

/// Advances the ball and decides what the line did to it: nothing, a post, a rebound, or a
/// goal against the player who owns that mouth.
///
/// The two radii here are different on purpose. The ball *rebounds* when its edge reaches the
/// paint, at `R − ballRadius`; it has *scored* only once its centre is past `R`, which can
/// only happen through a mouth. See `docs/RULES.md` §3.
enum GoalDetector {

    @discardableResult
    static func advance(ball: inout BallState,
                        arena: ArenaGeometry,
                        dt: Double,
                        tuning: Tuning) -> BoundaryOutcome {
        let previous = BallPhysics.integrate(&ball, dt: dt, tuning: tuning)

        if resolvePosts(ball: &ball, previous: previous, arena: arena, dt: dt, tuning: tuning) {
            // A post sits *on* the line, so a ball that just came off one can be a few
            // centimetres proud of the paint. Ease it back rather than bouncing it twice.
            let limit = arena.radius - tuning.ballRadius
            if ball.position.length > limit {
                ball.position = ball.position.normalized * limit
            }
            return .hitPost
        }

        let shell = arena.radius - tuning.ballRadius
        guard let contact = CollisionSolver.outwardCrossing(from: previous,
                                                            to: ball.position,
                                                            radius: shell) else {
            return .none
        }

        // Solid line: rebound.
        guard arena.openGoal(atBearing: contact.bearing) != nil else {
            CollisionSolver.bounceInsideBoundary(position: &ball.position,
                                                 velocity: &ball.velocity,
                                                 contact: contact,
                                                 boundaryRadius: arena.radius,
                                                 bodyRadius: tuning.ballRadius,
                                                 restitution: tuning.wallRestitution,
                                                 dt: dt)
            return .bounced
        }

        // Inside a mouth. It counts only once the centre is past the paint, and the bearing is
        // tested at that crossing rather than at the step's endpoint — over one step near the
        // line the bearing swings by up to 12% of a mouth's half-width, which is precisely the
        // margin between a goal and the inside of a post.
        if let throughLine = CollisionSolver.outwardCrossing(from: previous,
                                                            to: ball.position,
                                                            radius: arena.radius),
           let conceding = arena.openGoal(atBearing: throughLine.bearing) {
            return .scored(goal: conceding)
        }

        // In the mouth but not through it yet.
        return .none
    }

    /// Returns whether a post was struck. Stopping at the first is enough: the nearest two
    /// posts are 2.4 m apart and the ball covers at most 18 cm in a slice, so it cannot reach
    /// a second one in the same step.
    private static func resolvePosts(ball: inout BallState,
                                     previous: Vec2,
                                     arena: ArenaGeometry,
                                     dt: Double,
                                     tuning: Tuning) -> Bool {
        for post in arena.activePosts {
            if CollisionSolver.resolveAgainstStatic(previous: previous,
                                                    position: &ball.position,
                                                    velocity: &ball.velocity,
                                                    bodyRadius: tuning.ballRadius,
                                                    centre: post,
                                                    staticRadius: arena.postRadius,
                                                    restitution: tuning.postRestitution,
                                                    dt: dt) {
                return true
            }
        }
        return false
    }
}
