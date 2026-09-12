import Foundation

/// A colour as plain numbers. Deliberately not `UIColor`: nations are read by the simulation
/// layer, which imports no graphics framework. `KitPainter` converts these when it draws.
struct RGB: Equatable, Hashable {
    var r: Double
    var g: Double
    var b: Double

    init(_ r: Double, _ g: Double, _ b: Double) {
        self.r = r
        self.g = g
        self.b = b
    }

    /// From the usual hex literal, e.g. `RGB(hex: 0xFFDF00)`.
    init(hex: UInt32) {
        self.r = Double((hex >> 16) & 0xFF) / 255
        self.g = Double((hex >> 8) & 0xFF) / 255
        self.b = Double(hex & 0xFF) / 255
    }

    /// Hue in `0..<1`, used to keep two kits on the pitch from being confusable.
    var hue: Double {
        let maxC = max(r, g, b), minC = min(r, g, b)
        let delta = maxC - minC
        guard delta > 1e-9 else { return 0 }
        let h: Double
        if maxC == r { h = (g - b) / delta }
        else if maxC == g { h = 2 + (b - r) / delta }
        else { h = 4 + (r - g) / delta }
        return (h / 6).truncatingRemainder(dividingBy: 1) + (h < 0 ? 1 : 0)
    }

    var saturation: Double {
        let maxC = max(r, g, b)
        guard maxC > 1e-9 else { return 0 }
        return (maxC - min(r, g, b)) / maxC
    }

    var brightness: Double { max(r, g, b) }
}

/// How the shirt is painted.
enum KitPattern: String, Equatable, Hashable, CaseIterable {
    case solid
    case stripes
    case checks
    case sash
}

/// A footballing nation. Purely cosmetic — no kit may affect speed, power or anything else,
/// or one of them becomes "the good one". See `docs/GAME_DESIGN.md` §7.
struct Nation: Equatable, Hashable, Identifiable {
    let id: String
    let name: String
    let shirt: RGB
    let trim: RGB
    let pattern: KitPattern
    let shorts: RGB
    let socks: RGB
}

/// The 20 nations on offer. Recognisable national colours, not licensed kit reproductions.
enum NationCatalog {

    static let all: [Nation] = [
        Nation(id: "br", name: "Brazil", shirt: RGB(hex: 0xFFDF00), trim: RGB(hex: 0x009739),
               pattern: .solid, shorts: RGB(hex: 0x012169), socks: RGB(hex: 0xFFFFFF)),
        Nation(id: "ar", name: "Argentina", shirt: RGB(hex: 0x75AADB), trim: RGB(hex: 0xFFFFFF),
               pattern: .stripes, shorts: RGB(hex: 0x1A1A1A), socks: RGB(hex: 0xFFFFFF)),
        Nation(id: "fr", name: "France", shirt: RGB(hex: 0x002395), trim: RGB(hex: 0xFFFFFF),
               pattern: .solid, shorts: RGB(hex: 0xFFFFFF), socks: RGB(hex: 0xED2939)),
        Nation(id: "de", name: "Germany", shirt: RGB(hex: 0xF2F2F2), trim: RGB(hex: 0x1A1A1A),
               pattern: .sash, shorts: RGB(hex: 0x1A1A1A), socks: RGB(hex: 0xFFFFFF)),
        Nation(id: "es", name: "Spain", shirt: RGB(hex: 0xC60B1E), trim: RGB(hex: 0xFFC400),
               pattern: .solid, shorts: RGB(hex: 0x14235A), socks: RGB(hex: 0x14235A)),
        Nation(id: "it", name: "Italy", shirt: RGB(hex: 0x1B62A5), trim: RGB(hex: 0xFFFFFF),
               pattern: .solid, shorts: RGB(hex: 0xFFFFFF), socks: RGB(hex: 0x1B62A5)),
        Nation(id: "en", name: "England", shirt: RGB(hex: 0xFAFAFA), trim: RGB(hex: 0xCE1124),
               pattern: .solid, shorts: RGB(hex: 0x001E5C), socks: RGB(hex: 0xFFFFFF)),
        Nation(id: "pt", name: "Portugal", shirt: RGB(hex: 0x8C1420), trim: RGB(hex: 0x006600),
               pattern: .solid, shorts: RGB(hex: 0x006600), socks: RGB(hex: 0x8C1420)),
        Nation(id: "nl", name: "Netherlands", shirt: RGB(hex: 0xFF6200), trim: RGB(hex: 0xFFFFFF),
               pattern: .solid, shorts: RGB(hex: 0x1A1A1A), socks: RGB(hex: 0xFF6200)),
        Nation(id: "be", name: "Belgium", shirt: RGB(hex: 0xB8232F), trim: RGB(hex: 0xFAE042),
               pattern: .solid, shorts: RGB(hex: 0xB8232F), socks: RGB(hex: 0xB8232F)),
        Nation(id: "hr", name: "Croatia", shirt: RGB(hex: 0xFF3B30), trim: RGB(hex: 0xFFFFFF),
               pattern: .checks, shorts: RGB(hex: 0x171796), socks: RGB(hex: 0x171796)),
        Nation(id: "uy", name: "Uruguay", shirt: RGB(hex: 0x5CBFEB), trim: RGB(hex: 0x1A1A1A),
               pattern: .solid, shorts: RGB(hex: 0x1A1A1A), socks: RGB(hex: 0x1A1A1A)),
        Nation(id: "mx", name: "Mexico", shirt: RGB(hex: 0x006847), trim: RGB(hex: 0xFFFFFF),
               pattern: .solid, shorts: RGB(hex: 0xFFFFFF), socks: RGB(hex: 0xCE1126)),
        Nation(id: "us", name: "USA", shirt: RGB(hex: 0xF5F5F5), trim: RGB(hex: 0x0A3161),
               pattern: .sash, shorts: RGB(hex: 0x0A3161), socks: RGB(hex: 0xFFFFFF)),
        Nation(id: "jp", name: "Japan", shirt: RGB(hex: 0x1C1C5E), trim: RGB(hex: 0xFFFFFF),
               pattern: .solid, shorts: RGB(hex: 0x1C1C5E), socks: RGB(hex: 0x1C1C5E)),
        Nation(id: "ma", name: "Morocco", shirt: RGB(hex: 0xC1272D), trim: RGB(hex: 0x006233),
               pattern: .solid, shorts: RGB(hex: 0xC1272D), socks: RGB(hex: 0xC1272D)),
        Nation(id: "sn", name: "Senegal", shirt: RGB(hex: 0xEFEFEF), trim: RGB(hex: 0x00853F),
               pattern: .stripes, shorts: RGB(hex: 0x00853F), socks: RGB(hex: 0xFFFFFF)),
        Nation(id: "rs", name: "Serbia", shirt: RGB(hex: 0xA5242A), trim: RGB(hex: 0xFFFFFF),
               pattern: .solid, shorts: RGB(hex: 0x0C4076), socks: RGB(hex: 0xFFFFFF)),
        Nation(id: "pl", name: "Poland", shirt: RGB(hex: 0xFFFFFF), trim: RGB(hex: 0xDC143C),
               pattern: .solid, shorts: RGB(hex: 0xDC143C), socks: RGB(hex: 0xFFFFFF)),
        Nation(id: "dk", name: "Denmark", shirt: RGB(hex: 0xD00C33), trim: RGB(hex: 0xFFFFFF),
               pattern: .solid, shorts: RGB(hex: 0xFFFFFF), socks: RGB(hex: 0xD00C33)),
    ]

    static func nation(id: String) -> Nation? {
        all.first { $0.id == id }
    }

    /// Whether two kits are too close to tell apart mid-scrap. Several of the 20 sit in the
    /// same red or white family, so distinguishability is a gameplay requirement rather than
    /// a nicety — see `docs/ART_STYLE.md` §8.
    static func areConfusable(_ a: Nation, _ b: Nation) -> Bool {
        let bothPale = a.shirt.saturation < 0.2 && b.shirt.saturation < 0.2
        if bothPale {
            // Two white-ish kits are only separable by their trim.
            return hueSeparation(a.trim, b.trim) < 0.08
        }
        if a.shirt.saturation < 0.2 || b.shirt.saturation < 0.2 { return false }
        guard abs(a.shirt.brightness - b.shirt.brightness) < 0.35 else { return false }
        return hueSeparation(a.shirt, b.shirt) < 0.06
    }

    private static func hueSeparation(_ a: RGB, _ b: RGB) -> Double {
        let raw = abs(a.hue - b.hue)
        return min(raw, 1 - raw)
    }

    /// Deals distinct, mutually distinguishable nations to the bots, never the player's.
    static func dealOpponents(count: Int, avoiding chosen: Nation, rng: inout SeededRandom) -> [Nation] {
        var pool = rng.shuffled(all.filter { $0.id != chosen.id })
        var dealt: [Nation] = []

        while dealt.count < count, !pool.isEmpty {
            // Prefer a nation that clashes with nobody already on the pitch; if the pool is
            // exhausted of those, take the first rather than looping for ever.
            let index = pool.firstIndex { candidate in
                !areConfusable(candidate, chosen) && !dealt.contains { areConfusable($0, candidate) }
            } ?? 0
            dealt.append(pool.remove(at: index))
        }
        return dealt
    }
}
