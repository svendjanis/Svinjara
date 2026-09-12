import SpriteKit

/// A thumb button. The shoot one carries a ring that fills as the shot charges; the tackle one
/// dims while it is on cooldown, so both of them answer "can I do this right now?" without the
/// player looking away from the ball.
final class ActionButtonNode: SKNode {

    private let face: SKShapeNode
    private let ring: SKShapeNode
    private let label: SKLabelNode
    private let radius: CGFloat
    private let tint: UIColor

    init(radius: CGFloat, title: String, tint: UIColor) {
        self.radius = radius
        self.tint = tint

        face = SKShapeNode(circleOfRadius: radius)
        face.fillColor = UIColor(white: 1, alpha: 0.09)
        face.strokeColor = UIColor(white: 1, alpha: 0.28)
        face.lineWidth = 2

        ring = SKShapeNode()
        ring.strokeColor = tint
        ring.lineWidth = 5
        ring.lineCap = .round
        ring.fillColor = .clear

        label = SKLabelNode(text: title)
        label.fontName = "AvenirNextCondensed-Bold"
        label.fontSize = radius * 0.42
        label.verticalAlignmentMode = .center
        label.fontColor = UIColor(white: 1, alpha: 0.72)

        super.init()
        zPosition = Theme.Layer.hud.rawValue
        addChild(face)
        addChild(ring)
        addChild(label)
    }

    /// - Parameters:
    ///   - charge: `0...1`, drawn as a filling ring. Pass zero for a button with no charge.
    ///   - ready: false while the action is unavailable, which dims the whole button.
    func render(charge: CGFloat, pressed: Bool, ready: Bool = true) {
        face.fillColor = UIColor(white: 1, alpha: pressed ? 0.2 : 0.09)
        alpha = ready ? 1 : 0.4

        guard charge > 0.01 else {
            ring.path = nil
            return
        }
        let path = CGMutablePath()
        // Starts at the top and fills clockwise, which is how every power meter reads.
        path.addArc(center: .zero, radius: radius + 6,
                    startAngle: .pi / 2,
                    endAngle: .pi / 2 - charge * CGFloat(Angles.tau),
                    clockwise: true)
        ring.path = path
        ring.strokeColor = charge >= 0.999
            ? UIColor(red: 1, green: 0.45, blue: 0.2, alpha: 1)
            : tint
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not supported") }
}
