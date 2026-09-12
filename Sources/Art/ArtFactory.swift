import SpriteKit

/// Draws every texture once and keeps it. Nothing here touches the simulation; it only turns
/// data — a nation's colours, a face's seed — into pixels.
final class ArtFactory {

    private var figures: [String: SKTexture] = [:]
    private var ballTexture: SKTexture?

    func figure(nation: Nation, appearance: Appearance, diameter: CGFloat) -> SKTexture {
        let key = "\(nation.id)-\(appearance.style.rawValue)-\(appearance.skin)-\(appearance.hair)-\(Int(diameter))"
        if let cached = figures[key] { return cached }

        let texture = SKTexture(image: KitPainter.figure(nation: nation,
                                                         appearance: appearance,
                                                         diameter: diameter))
        texture.filteringMode = .linear
        figures[key] = texture
        return texture
    }

    func ball(diameter: CGFloat) -> SKTexture {
        if let cached = ballTexture { return cached }
        let texture = SKTexture(image: KitPainter.ball(diameter: diameter))
        texture.filteringMode = .linear
        ballTexture = texture
        return texture
    }
}
