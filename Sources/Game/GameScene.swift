import SpriteKit

/// Owns the match: steps the simulation on a fixed clock and draws whatever the resulting
/// state says. It holds no rules of its own — see `docs/ARCHITECTURE.md` §2.
///
/// M0: a placeholder that proves the bridge boots and the view is sized correctly. The real
/// renderer arrives in M3.
final class GameScene: SKScene {

    override func didMove(to view: SKView) {
        backgroundColor = Theme.concrete
        scaleMode = .resizeFill
        buildPlaceholder()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        guard size.width > 0 else { return }
        removeAllChildren()
        buildPlaceholder()
    }

    private func buildPlaceholder() {
        let radius = min(size.width, size.height) * Theme.pitchScreenFraction / 2

        let circle = SKShapeNode(circleOfRadius: radius)
        circle.position = CGPoint(x: size.width / 2, y: size.height / 2)
        circle.strokeColor = Theme.paint
        circle.lineWidth = 4
        circle.fillColor = .clear
        circle.zPosition = Theme.Layer.paintwork.rawValue
        addChild(circle)

        let label = SKLabelNode(text: "SVINJARA")
        label.fontName = "AvenirNextCondensed-Bold"
        label.fontSize = 34
        label.fontColor = Theme.paint
        label.position = CGPoint(x: size.width / 2, y: size.height / 2 - 12)
        label.zPosition = Theme.Layer.hud.rawValue
        addChild(label)
    }
}
