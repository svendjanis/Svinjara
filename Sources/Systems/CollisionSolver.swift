import Foundation

/// Every contact in the game, solved exactly. The world is discs inside a circle, so this is a
/// closed problem — see `docs/PHYSICS_AND_TUNING.md` §1 for why it is not `SKPhysicsBody`.
enum CollisionSolver {

    /// Where a moving body met a circle, and how far through the step it happened.
    struct Crossing: Equatable {
        /// Fraction of the step at which contact occurred, in `0...1`.
        let fraction: Double
        let point: Vec2

        var bearing: Double { point.angle }
    }

    // MARK: Circular boundary

    /// The first point at which the segment `p0 → p1` reaches `radius` from the origin
    /// travelling outward, solved analytically.
    ///
    /// Goals are decided by the bearing at which the ball crossed, and near the line one step
    /// swings the bearing by up to 0.74° — 12% of a mouth's 6.26° half-width. Taking the
    /// bearing from where the ball ended up rather than from where it crossed is therefore
    /// wrong by exactly the margin that separates a goal from the inside of a post.
    static func outwardCrossing(from p0: Vec2, to p1: Vec2, radius: Double) -> Crossing? {
        let c = p0.lengthSquared - radius * radius
        // Already at or beyond the radius when the step began.
        if c >= 0 { return Crossing(fraction: 0, point: p0) }

        let d = p1 - p0
        let a = d.lengthSquared
        guard a > 1e-18 else { return nil }

        let b = 2 * p0.dot(d)
        let discriminant = b * b - 4 * a * c
        guard discriminant >= 0 else { return nil }

        let t = (-b + discriminant.squareRoot()) / (2 * a)
        guard t >= 0, t <= 1 else { return nil }
        return Crossing(fraction: t, point: p0 + d * t)
    }

    /// Reflects a velocity about a unit normal, losing energy to restitution. A body already
    /// travelling away from the surface is left alone, which is what stops a body that is
    /// slightly embedded from being reflected twice on consecutive steps and jittering.
    static func reflect(_ velocity: Vec2, normal: Vec2, restitution: Double) -> Vec2 {
        let along = velocity.dot(normal)
        guard along < 0 else { return velocity }
        return (velocity - normal * (2 * along)) * restitution
    }

    /// Bounces a body off the inside of the circular boundary at a known contact point, then
    /// spends whatever is left of the step travelling along the new heading — otherwise a ball
    /// would visibly hesitate against the line on the step it bounced.
    static func bounceInsideBoundary(position: inout Vec2,
                                     velocity: inout Vec2,
                                     contact: Crossing,
                                     boundaryRadius: Double,
                                     bodyRadius: Double,
                                     restitution: Double,
                                     dt: Double) {
        let outward = contact.point.normalized
        guard outward != .zero else { return }

        velocity = reflect(velocity, normal: -outward, restitution: restitution)
        position = contact.point + velocity * ((1 - contact.fraction) * dt)

        // The remaining travel can itself leave the circle on a very shallow bounce; one
        // clamp is enough, because the reflected heading now points inward.
        let limit = boundaryRadius - bodyRadius
        if position.length > limit {
            position = position.normalized * limit
        }
    }

    /// Keeps a body inside the boundary by sliding along it: radial motion is removed,
    /// tangential motion is kept.
    ///
    /// Players do not bounce off the line, because bouncing feels broken when all you were
    /// doing was running along your own goal line. Returns whether contact happened.
    @discardableResult
    static func slideInsideBoundary(position: inout Vec2,
                                    velocity: inout Vec2,
                                    boundaryRadius: Double,
                                    bodyRadius: Double) -> Bool {
        let limit = boundaryRadius - bodyRadius
        let distance = position.length
        guard distance > limit, distance > 1e-12 else { return false }

        let outward = position / distance
        position = outward * limit

        let radial = velocity.dot(outward)
        if radial > 0 { velocity -= outward * radial }
        return true
    }

    // MARK: Disc against disc

    /// Two equal-mass discs. Overlap is split evenly and the impulse is applied along the
    /// contact normal. Returns whether they were touching.
    @discardableResult
    static func resolveEqualMass(positionA: inout Vec2, velocityA: inout Vec2,
                                 positionB: inout Vec2, velocityB: inout Vec2,
                                 radiusA: Double, radiusB: Double,
                                 restitution: Double) -> Bool {
        let delta = positionB - positionA
        let distance = delta.length
        let minimum = radiusA + radiusB
        guard distance < minimum else { return false }

        // Two bodies exactly on top of each other have no meaningful normal; pick one rather
        // than producing NaN and corrupting the whole state.
        let normal = distance > 1e-9 ? delta / distance : Vec2(x: 1, y: 0)

        let overlap = minimum - distance
        positionA -= normal * (overlap / 2)
        positionB += normal * (overlap / 2)

        let closing = (velocityB - velocityA).dot(normal)
        guard closing < 0 else { return true }

        let impulse = -(1 + restitution) * closing / 2
        velocityA -= normal * impulse
        velocityB += normal * impulse
        return true
    }

    /// A moving disc against an immovable one — the posts. Swept against the segment the body
    /// travelled rather than tested at its endpoint: at 120 Hz nothing can tunnel clean through
    /// a post, but a path that clips its edge can enter and leave the contact radius inside a
    /// single step, and those grazes are the deflections a player actually notices.
    @discardableResult
    static func resolveAgainstStatic(previous: Vec2,
                                     position: inout Vec2,
                                     velocity: inout Vec2,
                                     bodyRadius: Double,
                                     centre: Vec2,
                                     staticRadius: Double,
                                     restitution: Double,
                                     dt: Double) -> Bool {
        let sum = bodyRadius + staticRadius
        let from = previous - centre
        let overlapAtStart = from.lengthSquared - sum * sum

        // Resting against the post: push straight out and reflect in place.
        if overlapAtStart <= 0 {
            let current = position - centre
            let distance = current.length
            let normal = distance > 1e-9 ? current / distance : Vec2(x: 1, y: 0)
            position = centre + normal * sum
            velocity = reflect(velocity, normal: normal, restitution: restitution)
            return true
        }

        let travel = position - previous
        let a = travel.lengthSquared
        guard a > 1e-18 else { return false }

        let b = 2 * from.dot(travel)
        let discriminant = b * b - 4 * a * overlapAtStart
        guard discriminant >= 0 else { return false }

        // The earlier root is the near side of the post — the one actually struck.
        let t = (-b - discriminant.squareRoot()) / (2 * a)
        guard t >= 0, t <= 1 else { return false }

        let contact = previous + travel * t
        let normal = (contact - centre).normalized
        velocity = reflect(velocity, normal: normal, restitution: restitution)
        position = contact + velocity * ((1 - t) * dt)
        return true
    }
}
