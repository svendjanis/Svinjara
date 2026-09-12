import SpriteKit

/// The ball. Small, so it gets a hard shadow to stay findable in a five-way scrap.
final class BallNode: SKNode {

    private let sprite: SKSpriteNode
    private let shadow: SKShapeNode

    init(texture: SKTexture, diameter: CGFloat) {
        sprite = SKSpriteNode(texture: texture)
        sprite.size = CGSize(width: diameter, height: diameter)
        sprite.zPosition = Theme.Layer.ball.rawValue

        shadow = SKShapeNode(circleOfRadius: diameter * 0.5)
        shadow.fillColor = UIColor.black.withAlphaComponent(0.3)
        shadow.strokeColor = .clear
        shadow.position = CGPoint(x: diameter * 0.22, y: -diameter * 0.26)
        shadow.zPosition = Theme.Layer.shadow.rawValue

        super.init()
        addChild(shadow)
        addChild(sprite)
    }

    func render(position: CGPoint, roll: CGFloat) {
        self.position = position
        sprite.zRotation = roll
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not supported") }
}
