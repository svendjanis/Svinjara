import SpriteKit

/// One player's goal: a band of their own colour painted across the line, and two solid posts.
///
/// Colour on the ground is how the player answers "whose goal is that?" without a label, which
/// is the one thing they need to know constantly.
final class GoalNode: SKNode {

    private let arc = SKShapeNode()
    private var posts: [SKShapeNode] = []
    private let colour: UIColor

    init(goal: Int, arena: ArenaGeometry, colour: UIColor, centre: CGPoint,
         pointsPerMetre: CGFloat, lineWidth: CGFloat) {
        self.colour = colour
        super.init()

        let bearing = arena.bearings[goal]
        let radius = CGFloat(arena.radius) * pointsPerMetre

        let path = CGMutablePath()
        path.addArc(center: centre, radius: radius,
                    startAngle: CGFloat(bearing - arena.mouthHalfAngle),
                    endAngle: CGFloat(bearing + arena.mouthHalfAngle),
                    clockwise: false)
        arc.path = path
        arc.strokeColor = colour
        arc.lineWidth = lineWidth * 2.4
        arc.lineCap = .butt
        arc.zPosition = Theme.Layer.paintwork.rawValue + 1
        addChild(arc)

        let postRadius = max(2, CGFloat(arena.postRadius) * pointsPerMetre)
        for post in [arena.posts(of: goal).left, arena.posts(of: goal).right] {
            let node = SKShapeNode(circleOfRadius: postRadius)
            node.position = CGPoint(x: centre.x + CGFloat(post.x) * pointsPerMetre,
                                    y: centre.y + CGFloat(post.y) * pointsPerMetre)
            node.fillColor = Theme.paint
            node.strokeColor = UIColor.black.withAlphaComponent(0.45)
            node.lineWidth = 1
            node.zPosition = Theme.Layer.post.rawValue
            posts.append(node)
            addChild(node)
        }
    }

    /// Bricked up. The arc becomes a visible repair rather than original surface, and the
    /// posts come out with it — matching what the physics now believes.
    func seal() {
        arc.strokeColor = Theme.sealed
        arc.lineWidth = arc.lineWidth * 0.8
        for post in posts { post.removeFromParent() }
        posts.removeAll()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not supported") }
}
