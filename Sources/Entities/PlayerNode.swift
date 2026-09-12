import SpriteKit

/// One figure on the pitch: a shadow flat on the ground, the figure floating above it, and —
/// for the human — an outline so they can always find themselves.
///
/// The gap between figure and shadow is what says the player is standing on the concrete
/// rather than painted onto it.
final class PlayerNode: SKNode {

    private let figure: SKSpriteNode
    private let shadow: SKShapeNode
    private var ring: SKShapeNode?
    private let lift: CGFloat

    init(texture: SKTexture, diameter: CGFloat, footprint: CGSize, lift: CGFloat, isHuman: Bool) {
        self.lift = lift

        figure = SKSpriteNode(texture: texture)
        figure.size = CGSize(width: diameter, height: diameter)
        figure.position = CGPoint(x: 0, y: lift)
        figure.zPosition = Theme.Layer.player.rawValue

        // The shadow lies in the ground plane, so it is squashed by the tilt while the figure
        // above it is not.
        shadow = SKShapeNode(ellipseOf: footprint)
        shadow.fillColor = UIColor.black.withAlphaComponent(0.34)
        shadow.strokeColor = .clear
        shadow.zPosition = Theme.Layer.shadow.rawValue

        super.init()
        addChild(shadow)
        addChild(figure)

        if isHuman {
            // Drawn on the ground at their feet rather than around the figure: thin and
            // bright, findable at a glance, never competing with the ball for attention.
            let outline = SKShapeNode(ellipseOf: CGSize(width: footprint.width * 1.45,
                                                        height: footprint.height * 1.45))
            outline.strokeColor = UIColor(white: 1, alpha: 0.9)
            outline.lineWidth = 2
            outline.fillColor = .clear
            outline.zPosition = Theme.Layer.shadow.rawValue + 0.1
            addChild(outline)
            ring = outline
        }
    }

    /// The figure rotates; the shadow does not, because the sun does not move.
    func render(position: CGPoint, facing: CGFloat, staggered: Bool, dashing: Bool, depth: CGFloat) {
        self.position = position
        zPosition = depth
        figure.zRotation = facing
        figure.alpha = staggered ? 0.62 : 1
        // A lunge lifts you slightly off the floor; a stagger drops you toward it.
        figure.position = CGPoint(x: 0, y: dashing ? lift * 1.25 : (staggered ? lift * 0.7 : lift))
        figure.setScale(dashing ? 1.08 : 1)
    }

    func fadeOutEliminated() {
        run(.sequence([.fadeOut(withDuration: 0.5), .removeFromParent()]))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not supported") }
}
