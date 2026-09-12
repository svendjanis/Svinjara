import SpriteKit

/// The ball. Small, so it gets a hard shadow on the ground to stay findable in a five-way
/// scrap — and the shadow is also what keeps it sitting on the surface rather than hovering.
final class BallNode: SKNode {

    private let sprite: SKSpriteNode
    private let shadow: SKShapeNode

    init(texture: SKTexture, diameter: CGFloat, footprint: CGSize, lift: CGFloat) {
        sprite = SKSpriteNode(texture: texture)
        sprite.size = CGSize(width: diameter, height: diameter)
        sprite.position = CGPoint(x: 0, y: lift)
        sprite.zPosition = Theme.Layer.ball.rawValue

        shadow = SKShapeNode(ellipseOf: footprint)
        shadow.fillColor = UIColor.black.withAlphaComponent(0.36)
        shadow.strokeColor = .clear
        shadow.zPosition = Theme.Layer.shadow.rawValue

        super.init()
        addChild(shadow)
        addChild(sprite)
    }

    func render(position: CGPoint, roll: CGFloat, depth: CGFloat) {
        self.position = position
        zPosition = depth
        sprite.zRotation = roll
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not supported") }
}
