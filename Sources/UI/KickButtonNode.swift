import SpriteKit

/// The kick button, with a ring that fills as the shot charges — the player has to be able to
/// see their power without looking away from the ball, so the ring is large and the fill is
/// the only thing that moves.
final class KickButtonNode: SKNode {

    private let face: SKShapeNode
    private let ring: SKShapeNode
    private let radius: CGFloat

    init(radius: CGFloat) {
        self.radius = radius

        face = SKShapeNode(circleOfRadius: radius)
        face.fillColor = UIColor(white: 1, alpha: 0.08)
        face.strokeColor = UIColor(white: 1, alpha: 0.25)
        face.lineWidth = 2

        ring = SKShapeNode()
        ring.strokeColor = UIColor(red: 1, green: 0.82, blue: 0.25, alpha: 0.95)
        ring.lineWidth = 5
        ring.lineCap = .round
        ring.fillColor = .clear

        super.init()
        zPosition = Theme.Layer.hud.rawValue
        addChild(face)
        addChild(ring)
    }

    /// `charge` is `0...1`.
    func render(charge: CGFloat, pressed: Bool) {
        face.fillColor = UIColor(white: 1, alpha: pressed ? 0.16 : 0.08)

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
            : UIColor(red: 1, green: 0.82, blue: 0.25, alpha: 0.95)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not supported") }
}
