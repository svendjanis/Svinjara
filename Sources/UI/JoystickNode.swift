import SpriteKit

/// The floating thumb stick. It appears where the thumb lands rather than sitting in a fixed
/// spot, so there is nothing to find and nothing to miss.
final class JoystickNode: SKNode {

    private let base: SKShapeNode
    private let knob: SKShapeNode

    init(radius: CGFloat) {
        base = SKShapeNode(circleOfRadius: radius)
        base.fillColor = UIColor(white: 1, alpha: 0.06)
        base.strokeColor = UIColor(white: 1, alpha: 0.22)
        base.lineWidth = 2

        knob = SKShapeNode(circleOfRadius: radius * 0.42)
        knob.fillColor = UIColor(white: 1, alpha: 0.30)
        knob.strokeColor = UIColor(white: 1, alpha: 0.5)
        knob.lineWidth = 1.5

        super.init()
        zPosition = Theme.Layer.hud.rawValue
        alpha = 0
        addChild(base)
        addChild(knob)
    }

    func show(origin: CGPoint, offset: CGPoint) {
        position = origin
        knob.position = offset
        alpha = 1
    }

    func hide() {
        alpha = 0
        knob.position = .zero
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not supported") }
}
