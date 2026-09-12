import XCTest
@testable import Svinjara

final class NationCatalogTests: XCTestCase {

    func testThereAreTwentyNationsWithUniqueIdentity() {
        XCTAssertEqual(NationCatalog.all.count, 20)
        XCTAssertEqual(Set(NationCatalog.all.map(\.id)).count, 20)
        XCTAssertEqual(Set(NationCatalog.all.map(\.name)).count, 20)
    }

    func testEveryNationLooksUpByItsIdentifier() {
        for nation in NationCatalog.all {
            XCTAssertEqual(NationCatalog.nation(id: nation.id), nation)
        }
        XCTAssertNil(NationCatalog.nation(id: "zz"))
    }

    func testKitColoursAreInRange() {
        for nation in NationCatalog.all {
            for colour in [nation.shirt, nation.trim, nation.shorts, nation.socks] {
                XCTAssertTrue((0...1).contains(colour.r))
                XCTAssertTrue((0...1).contains(colour.g))
                XCTAssertTrue((0...1).contains(colour.b))
            }
            XCTAssertNotEqual(nation.shirt, nation.trim, "\(nation.name) has no contrast")
        }
    }

    func testHexInitialiserMatchesComponents() {
        let white = RGB(hex: 0xFFFFFF)
        XCTAssertEqual(white.r, 1, accuracy: 1e-9)
        XCTAssertEqual(white.g, 1, accuracy: 1e-9)
        XCTAssertEqual(white.b, 1, accuracy: 1e-9)

        let red = RGB(hex: 0xFF0000)
        XCTAssertEqual(red.r, 1, accuracy: 1e-9)
        XCTAssertEqual(red.g, 0, accuracy: 1e-9)
        XCTAssertEqual(red.hue, 0, accuracy: 1e-9)
        XCTAssertEqual(red.saturation, 1, accuracy: 1e-9)
    }

    /// Several of the 20 sit in the same red or white family, so telling them apart mid-scrap
    /// is a gameplay requirement rather than a nicety. `dealOpponents` is what enforces it.
    func testConfusableKitsAreRecognisedAsSuch() {
        let spain = NationCatalog.nation(id: "es")!
        let morocco = NationCatalog.nation(id: "ma")!
        let brazil = NationCatalog.nation(id: "br")!

        XCTAssertTrue(NationCatalog.areConfusable(spain, morocco), "two reds")
        XCTAssertFalse(NationCatalog.areConfusable(spain, brazil), "red against yellow")
        XCTAssertTrue(NationCatalog.areConfusable(brazil, brazil), "a kit always clashes with itself")
    }

    func testOpponentsAreDistinctAndNeverThePlayersNation() {
        var rng = SeededRandom(seed: 3)
        for chosen in NationCatalog.all {
            let opponents = NationCatalog.dealOpponents(count: 4, avoiding: chosen, rng: &rng)
            XCTAssertEqual(opponents.count, 4)
            XCTAssertEqual(Set(opponents.map(\.id)).count, 4, "no nation twice")
            XCTAssertFalse(opponents.contains(chosen), "bots never take the player's nation")
        }
    }

    func testADealtLineupIsMostlyFreeOfClashes() {
        var rng = SeededRandom(seed: 11)
        var clashes = 0
        let deals = 200

        for index in 0..<deals {
            let chosen = NationCatalog.all[index % NationCatalog.all.count]
            let lineup = [chosen] + NationCatalog.dealOpponents(count: 4, avoiding: chosen, rng: &rng)
            for a in 0..<lineup.count {
                for b in (a + 1)..<lineup.count where NationCatalog.areConfusable(lineup[a], lineup[b]) {
                    clashes += 1
                }
            }
        }
        XCTAssertLessThan(clashes, deals / 10, "\(clashes) clashing pairs across \(deals) lineups")
    }

    func testDealingIsReproducible() {
        var first = SeededRandom(seed: 42)
        var second = SeededRandom(seed: 42)
        let chosen = NationCatalog.all[7]
        XCTAssertEqual(NationCatalog.dealOpponents(count: 4, avoiding: chosen, rng: &first),
                       NationCatalog.dealOpponents(count: 4, avoiding: chosen, rng: &second))
    }

    // MARK: Faces

    func testFacesVaryBetweenPlayersOfTheSameNation() {
        let faces = (0..<5).map { AppearanceFactory.make(seed: UInt64($0) &* 0x9E37_79B9) }
        XCTAssertGreaterThan(Set(faces.map { "\($0.skin)\($0.hair)\($0.style.rawValue)" }).count, 1)
    }

    func testAFaceIsReproducibleFromItsSeed() {
        XCTAssertEqual(AppearanceFactory.make(seed: 99), AppearanceFactory.make(seed: 99))
    }

    func testFacesUseTheSharedPalettes() {
        for seed in 0..<400 {
            let face = AppearanceFactory.make(seed: UInt64(seed))
            XCTAssertTrue(AppearanceFactory.skinTones.contains(face.skin))
            XCTAssertTrue(AppearanceFactory.hairColours.contains(face.hair))
        }
    }

    /// Every hair style should turn up, or one of them is unreachable and the figures are less
    /// varied than the code claims.
    func testEveryHairStyleIsReachable() {
        var seen = Set<HairStyle>()
        for seed in 0..<400 { seen.insert(AppearanceFactory.make(seed: UInt64(seed)).style) }
        XCTAssertEqual(seen.count, HairStyle.allCases.count)
    }
}
