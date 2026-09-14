import SpriteKit

/// The standings, readable without looking away from the ball.
///
/// Five chips in goal order, each a kit colour and one pip per concede allowed. No numbers and
/// no names: a row of dots is read faster than a digit, and the whole point is that a glance is
/// enough.
final class HUDNode: SKNode {

    private struct Chip {
        let container: SKNode
        let plate: SKShapeNode
        let swatch: SKShapeNode
        let pips: [SKShapeNode]
    }

    private var chips: [Chip] = []
    private let banner: SKNode
    private let bannerPlate: SKShapeNode
    private let bannerLabel: SKLabelNode
    private let limit: Int

    init(players: [PlayerState], sceneSize: CGSize, limit: Int) {
        self.limit = limit

        bannerPlate = SKShapeNode(rectOf: CGSize(width: sceneSize.width, height: 54))
        bannerPlate.strokeColor = .clear

        bannerLabel = SKLabelNode(text: "")
        bannerLabel.fontName = "AvenirNextCondensed-Bold"
        bannerLabel.fontSize = 28
        bannerLabel.verticalAlignmentMode = .center
        bannerLabel.fontColor = .white

        banner = SKNode()
        banner.addChild(bannerPlate)
        banner.addChild(bannerLabel)
        banner.position = CGPoint(x: sceneSize.width / 2, y: sceneSize.height * 0.58)
        banner.alpha = 0
        banner.zPosition = Theme.Layer.hud.rawValue + 10

        super.init()
        zPosition = Theme.Layer.hud.rawValue
        addChild(banner)

        let chipWidth: CGFloat = 74
        let spacing: CGFloat = 8
        let total = CGFloat(players.count) * chipWidth + CGFloat(players.count - 1) * spacing
        var x = (sceneSize.width - total) / 2 + chipWidth / 2

        for player in players {
            chips.append(makeChip(player: player, width: chipWidth,
                                  at: CGPoint(x: x, y: sceneSize.height - 26)))
            x += chipWidth + spacing
        }
    }

    private func makeChip(player: PlayerState, width: CGFloat, at point: CGPoint) -> Chip {
        let container = SKNode()
        container.position = point
        addChild(container)

        let isHuman = player.index == 0
        let height: CGFloat = isHuman ? 32 : 27

        let plate = SKShapeNode(rectOf: CGSize(width: width, height: height), cornerRadius: 7)
        plate.fillColor = UIColor.black.withAlphaComponent(0.32)
        plate.strokeColor = isHuman ? UIColor(white: 1, alpha: 0.85) : UIColor(white: 1, alpha: 0.12)
        plate.lineWidth = isHuman ? 1.8 : 1
        container.addChild(plate)

        let swatch = SKShapeNode(rectOf: CGSize(width: 15, height: 15), cornerRadius: 3)
        swatch.fillColor = player.nation.shirt.uiColor
        swatch.strokeColor = player.nation.trim.uiColor
        swatch.lineWidth = 2
        swatch.position = CGPoint(x: -width / 2 + 14, y: 0)
        container.addChild(swatch)

        var pips: [SKShapeNode] = []
        let pipSpacing: CGFloat = 7.4
        let firstX = -width / 2 + 28
        for index in 0..<limit {
            let pip = SKShapeNode(circleOfRadius: 2.6)
            pip.strokeColor = .clear
            pip.fillColor = UIColor(white: 1, alpha: 0.18)
            pip.position = CGPoint(x: firstX + CGFloat(index) * pipSpacing, y: 0)
            container.addChild(pip)
            pips.append(pip)
        }

        return Chip(container: container, plate: plate, swatch: swatch, pips: pips)
    }

    func update(players: [PlayerState]) {
        for player in players {
            guard player.index < chips.count else { continue }
            let chip = chips[player.index]

            for (index, pip) in chip.pips.enumerated() {
                pip.fillColor = index < player.conceded
                    ? player.nation.shirt.uiColor
                    : UIColor(white: 1, alpha: 0.18)
            }

            // Knocked out: the whole chip goes flat, so the eye stops counting them.
            let alive = player.isAlive
            chip.container.alpha = alive ? 1 : 0.4
            chip.swatch.fillColor = alive
                ? player.nation.shirt.uiColor
                : player.nation.shirt.uiColor.darkened(by: 0.3)
        }
    }

    /// A band in the conceding player's colour, for the length of the celebration.
    func announce(conceded by: PlayerState, ownGoal: Bool, duration: TimeInterval) {
        bannerLabel.text = ownGoal
            ? "\(by.nation.name.uppercased()) — OWN GOAL"
            : "\(by.nation.name.uppercased()) LETS ONE IN"
        bannerPlate.fillColor = by.nation.shirt.uiColor.withAlphaComponent(0.9)
        bannerLabel.fontColor = by.nation.shirt.brightness > 0.7 ? .black : .white

        banner.removeAllActions()
        banner.run(.sequence([
            .fadeIn(withDuration: 0.12),
            .wait(forDuration: duration - 0.3),
            .fadeOut(withDuration: 0.18),
        ]))
    }

    func announce(eliminated: PlayerState) {
        bannerLabel.text = "\(eliminated.nation.name.uppercased()) IS OUT"
        bannerPlate.fillColor = Theme.sealed.withAlphaComponent(0.95)
        bannerLabel.fontColor = .white

        banner.removeAllActions()
        banner.run(.sequence([
            .fadeIn(withDuration: 0.12),
            .wait(forDuration: 1.5),
            .fadeOut(withDuration: 0.2),
        ]))
    }

    /// Takes a standing banner back down after a beat.
    func dismissAfter(_ seconds: TimeInterval) {
        banner.run(.sequence([.wait(forDuration: seconds), .fadeOut(withDuration: 0.2)]))
    }

    /// A banner that stays up, for the end of the match.
    func announce(text: String, colour: UIColor) {
        bannerLabel.text = text
        bannerPlate.fillColor = colour.withAlphaComponent(0.95)
        bannerLabel.fontColor = .white
        banner.removeAllActions()
        banner.run(.fadeIn(withDuration: 0.15))
    }

    func announce(winner: PlayerState) {
        bannerLabel.text = "\(winner.nation.name.uppercased()) WINS"
        bannerPlate.fillColor = winner.nation.shirt.uiColor.withAlphaComponent(0.95)
        bannerLabel.fontColor = winner.nation.shirt.brightness > 0.7 ? .black : .white
        banner.removeAllActions()
        banner.run(.fadeIn(withDuration: 0.15))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not supported") }
}
