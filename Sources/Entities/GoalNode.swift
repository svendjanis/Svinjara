import SpriteKit

/// One player's goal: a band of their own colour painted across the line, and two posts that
/// actually stand up off it.
///
/// Colour on the ground is how the player answers "whose goal is that?" without a label, which
/// is the one thing they need to know constantly.
final class GoalNode: SKNode {

    private let arc = SKShapeNode()
    private var posts: [SKNode] = []

    init(goal: Int, arena: ArenaGeometry, colour: UIColor, projection: Projection,
         lineWidth: CGFloat) {
        super.init()

        let bearing = arena.bearings[goal]

        arc.path = projection.arc(radius: arena.radius,
                                  from: bearing - arena.mouthHalfAngle,
                                  to: bearing + arena.mouthHalfAngle)
        arc.strokeColor = colour
        arc.lineWidth = lineWidth * 2.4
        arc.lineCap = .butt
        arc.zPosition = Theme.Layer.paintwork.rawValue + 1
        addChild(arc)

        for foot in [arena.posts(of: goal).left, arena.posts(of: goal).right] {
            addChild(makePost(at: foot, projection: projection, radius: arena.postRadius))
        }
    }

    /// A post is its shadow on the ground, a shaft rising from it, and a cap on top. The gap
    /// between cap and shadow is the entire reason it reads as standing rather than painted.
    private func makePost(at foot: Vec2, projection: Projection, radius: Double) -> SKNode {
        let node = SKNode()
        let base = projection.point(foot)
        let top = projection.point(foot, height: Theme.postHeight)
        let thickness = max(2.5, projection.length(radius) * 1.6)

        let shadow = SKShapeNode(ellipseOf: projection.footprint(radius: radius * 1.6))
        shadow.position = base
        shadow.fillColor = UIColor.black.withAlphaComponent(0.35)
        shadow.strokeColor = .clear
        shadow.zPosition = Theme.Layer.shadow.rawValue
        node.addChild(shadow)

        let shaft = SKShapeNode()
        let path = CGMutablePath()
        path.move(to: base)
        path.addLine(to: top)
        shaft.path = path
        shaft.strokeColor = Theme.paint
        shaft.lineWidth = thickness
        shaft.lineCap = .round
        shaft.zPosition = Theme.Layer.post.rawValue
        node.addChild(shaft)

        // A darker edge down one side, so the shaft reads as round rather than as a stripe.
        let edge = SKShapeNode()
        let edgePath = CGMutablePath()
        edgePath.move(to: CGPoint(x: base.x + thickness * 0.26, y: base.y))
        edgePath.addLine(to: CGPoint(x: top.x + thickness * 0.26, y: top.y))
        edge.path = edgePath
        edge.strokeColor = UIColor.black.withAlphaComponent(0.28)
        edge.lineWidth = thickness * 0.42
        edge.lineCap = .round
        edge.zPosition = Theme.Layer.post.rawValue + 0.1
        node.addChild(edge)

        posts.append(node)
        return node
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
