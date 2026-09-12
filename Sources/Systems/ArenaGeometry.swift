import Foundation

/// The circle, the five goal mouths on it, and the posts that frame them.
///
/// Sealing lives here rather than in the match state because sealing is a change to the
/// *geometry* — after it, the arc is wall for every purpose, and no caller should have to
/// remember to consult a separate set of dead players before bouncing a ball.
struct ArenaGeometry: Equatable {

    let radius: Double
    let postRadius: Double

    /// Bearing of the centre of each goal mouth, indexed by the owning player.
    let bearings: [Double]

    /// Half the angular width of a mouth. Derived from the chord so the mouth is a real
    /// distance on the ground rather than a number of degrees that would change meaning if the
    /// pitch were resized.
    let mouthHalfAngle: Double

    /// False once the owner has been eliminated: the arc becomes wall and its posts vanish.
    private(set) var isOpen: [Bool]

    init(tuning: Tuning = .default) {
        self.radius = tuning.pitchRadius
        self.postRadius = tuning.postRadius
        self.mouthHalfAngle = asin(min(1, tuning.goalMouthChord / (2 * tuning.pitchRadius)))

        // Goal 0 sits at the bottom of the screen and always belongs to the human, so the
        // renderer needs no rotation of its own and "back" always means "toward my goal".
        let spacing = Angles.tau / Double(tuning.goalCount)
        self.bearings = (0..<tuning.goalCount).map { Angles.normalize(-Double.pi / 2 + Double($0) * spacing) }
        self.isOpen = Array(repeating: true, count: tuning.goalCount)
    }

    var goalCount: Int { bearings.count }

    mutating func seal(_ goal: Int) {
        isOpen[goal] = false
    }

    /// The goal whose open mouth spans this bearing, or nil for wall.
    func openGoal(atBearing bearing: Double) -> Int? {
        for goal in 0..<goalCount where isOpen[goal] {
            if Angles.separation(bearing, bearings[goal]) <= mouthHalfAngle { return goal }
        }
        return nil
    }

    /// True if this bearing is solid line rather than an open mouth.
    func isWall(atBearing bearing: Double) -> Bool {
        openGoal(atBearing: bearing) == nil
    }

    /// The two post centres for a goal, whether or not it is still open. Posts sit *on* the
    /// line at the ends of the mouth, so they straddle it exactly as painted posts would.
    func posts(of goal: Int) -> (left: Vec2, right: Vec2) {
        let b = bearings[goal]
        return (Vec2(angle: b - mouthHalfAngle, length: radius),
                Vec2(angle: b + mouthHalfAngle, length: radius))
    }

    /// Every post currently on the pitch. Sealed goals contribute none — the arc is flat wall.
    var activePosts: [Vec2] {
        var result: [Vec2] = []
        result.reserveCapacity(goalCount * 2)
        for goal in 0..<goalCount where isOpen[goal] {
            let pair = posts(of: goal)
            result.append(pair.left)
            result.append(pair.right)
        }
        return result
    }

    /// Where a player stands at kickoff: in front of their own goal, facing the centre.
    func homeSpot(of goal: Int, fraction: Double) -> Vec2 {
        Vec2(angle: bearings[goal], length: radius * fraction)
    }

    /// The bearing from a point to the centre of a goal's mouth.
    func aimBearing(from point: Vec2, at goal: Int) -> Double {
        (mouthCentre(of: goal) - point).angle
    }

    /// The point on the line at the middle of a goal's mouth.
    func mouthCentre(of goal: Int) -> Vec2 {
        Vec2(angle: bearings[goal], length: radius)
    }
}
