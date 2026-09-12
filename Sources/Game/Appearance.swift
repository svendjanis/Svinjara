import Foundation

enum HairStyle: Int, Equatable, CaseIterable {
    case short
    case fade
    case curly
    case long
    case bald
}

/// What a figure looks like above the shirt.
struct Appearance: Equatable {
    let skin: RGB
    let hair: RGB
    let style: HairStyle
}

/// Builds a figure's face from a seed.
///
/// Every nation draws from the same full range of skin tones and hair colours, and the
/// variation is per *player* rather than per nation. That is both the accurate choice — a
/// modern national squad is not one look repeated eleven times — and the one that actually
/// achieves the goal, which is that five figures on the pitch read as five different people.
/// Nations are told apart by their kit.
enum AppearanceFactory {

    static let skinTones: [RGB] = [
        RGB(hex: 0xF5D6BE), RGB(hex: 0xEFC8A6), RGB(hex: 0xE0B18B),
        RGB(hex: 0xC68A62), RGB(hex: 0xA9673F), RGB(hex: 0x8A5030),
        RGB(hex: 0x653A22), RGB(hex: 0x4A2A19),
    ]

    static let hairColours: [RGB] = [
        RGB(hex: 0x1A1310), RGB(hex: 0x2E211A), RGB(hex: 0x4A3323),
        RGB(hex: 0x6B4A2E), RGB(hex: 0x9A6B3C), RGB(hex: 0xC9A05A),
        RGB(hex: 0xE0C58A), RGB(hex: 0x8C8C8C),
    ]

    static func make(seed: UInt64) -> Appearance {
        var rng = SeededRandom(seed: seed)
        let skin = rng.pick(skinTones)

        // Hair is biased toward the darker end and loosely toward the skin tone, so a figure
        // reads as a person rather than as a random pair of swatches.
        let skinIndex = skinTones.firstIndex(of: skin) ?? 0
        let ceiling = max(1, hairColours.count - 1 - skinIndex / 2)
        let hair = hairColours[rng.int(in: 0...ceiling)]

        return Appearance(skin: skin,
                          hair: hair,
                          style: HairStyle(rawValue: rng.int(in: 0...(HairStyle.allCases.count - 1)))!)
    }
}
