import SpriteKit

/// One figure on the pitch, plus its shadow and — for the human — an outline so they can
/// always find themselves.
final class PlayerNode: SKNode {

    private let figure: SKSpriteNode
    private let shadow: SKShapeNode
    private var ring: SKShapeNode?

    init(texture: SKTexture, diameter: CGFloat, isHuman: Bool) {
        figure = SKSpriteNode(texture: texture)
        figure.size = CGSize(width: diameter, height: diameter)
        figure.zPosition = Theme.Layer.player.rawValue

        // Smaller than the figure, or it reads as a dark ring around every player rather than
        // as a shadow under one.
        shadow = SKShapeNode(ellipseOf: CGSize(width: diameter * 0.60, height: diameter * 0.54))
        shadow.fillColor = UIColor.black.withAlphaComponent(0.22)
        shadow.strokeColor = .clear
        shadow.position = CGPoint(x: diameter * 0.05, y: -diameter * 0.07)
        shadow.zPosition = Theme.Layer.shadow.rawValue

        super.init()
        addChild(shadow)
        addChild(figure)

        if isHuman {
            // Thin and bright rather than flashy: findable at a glance, never competing with
            // the ball for attention.
            let outline = SKShapeNode(circleOfRadius: diameter * 0.52)
            outline.strokeColor = UIColor(white: 1, alpha: 0.9)
            outline.lineWidth = 2
            outline.fillColor = .clear
            outline.zPosition = Theme.Layer.player.rawValue - 1
            addChild(outline)
            ring = outline
        }
    }

    /// The figure rotates; the shadow does not, because the sun does not move.
    func render(position: CGPoint, facing: CGFloat, staggered: Bool, dashing: Bool) {
        self.position = position
        figure.zRotation = facing
        figure.alpha = staggered ? 0.62 : 1
        figure.setScale(dashing ? 1.08 : 1)
        ring?.zRotation = 0
    }

    func fadeOutEliminated() {
        run(.sequence([.fadeOut(withDuration: 0.5), .removeFromParent()]))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not supported") }
}
