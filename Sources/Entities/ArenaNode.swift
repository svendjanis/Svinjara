import SpriteKit

/// The court: concrete, and the white circle painted on it. Static for the life of a match.
final class ArenaNode: SKNode {

    init(sceneSize: CGSize, projection: Projection, radius: Double, lineWidth: CGFloat) {
        super.init()

        let surface = SKSpriteNode(texture: ConcreteTexture.make(size: sceneSize))
        surface.position = CGPoint(x: sceneSize.width / 2, y: sceneSize.height / 2)
        surface.size = sceneSize
        surface.zPosition = Theme.Layer.surface.rawValue
        addChild(surface)

        let paint = SKSpriteNode(texture: CourtPaint.make(size: sceneSize, projection: projection,
                                                          radius: radius, lineWidth: lineWidth))
        paint.position = CGPoint(x: sceneSize.width / 2, y: sceneSize.height / 2)
        paint.size = sceneSize
        paint.zPosition = Theme.Layer.paintwork.rawValue
        addChild(paint)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not supported") }
}
