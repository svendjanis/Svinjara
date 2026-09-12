import XCTest
@testable import Svinjara

/// An in-memory store so the suite never writes to the real defaults — a test that does
/// quietly changes how the app behaves on the machine that ran it.
final class InMemoryStore: LocalStore {
    var lastNationID: String?
    var difficultyID: String?
    var soundEnabled: Bool = true
    var stats = CareerStats()
}

final class LocalStoreTests: XCTestCase {

    func testAFirstRunHasSaneDefaults() {
        let model = AppModel(store: InMemoryStore())
        XCTAssertEqual(model.screen, .menu)
        XCTAssertEqual(model.difficulty, .normal)
        XCTAssertTrue(model.soundEnabled)
        XCTAssertEqual(model.stats, CareerStats())
        XCTAssertEqual(model.chosenNation, NationCatalog.all[0])
    }

    func testChoicesRoundTripThroughTheStore() {
        let store = InMemoryStore()
        let model = AppModel(store: store)

        let croatia = NationCatalog.nation(id: "hr")!
        model.choose(croatia)
        model.choose(BotDifficulty.hard)
        model.soundEnabled = false

        XCTAssertEqual(store.lastNationID, "hr")
        XCTAssertEqual(store.difficultyID, "hard")
        XCTAssertFalse(store.soundEnabled)

        let reopened = AppModel(store: store)
        XCTAssertEqual(reopened.chosenNation, croatia)
        XCTAssertEqual(reopened.difficulty, .hard)
        XCTAssertFalse(reopened.soundEnabled)
    }

    func testAnUnknownStoredNationFallsBackRatherThanCrashing() {
        let store = InMemoryStore()
        store.lastNationID = "zz"
        store.difficultyID = "impossible"

        let model = AppModel(store: store)
        XCTAssertEqual(model.chosenNation, NationCatalog.all[0])
        XCTAssertEqual(model.difficulty, .normal)
    }

    func testKickingOffDealsALineupLedByThePlayer() {
        let model = AppModel(store: InMemoryStore())
        let spain = NationCatalog.nation(id: "es")!
        model.choose(spain)
        model.kickOff()

        XCTAssertEqual(model.screen, .match)
        XCTAssertEqual(model.lineup.count, 5)
        XCTAssertEqual(model.lineup.first, spain)
        XCTAssertEqual(Set(model.lineup.map(\.id)).count, 5)
        XCTAssertNil(model.summary, "a new match starts with no result")
    }

    func testEachKickOffDealsAFreshMatch() {
        let model = AppModel(store: InMemoryStore())
        model.kickOff()
        let first = model.matchSeed
        model.kickOff()
        XCTAssertNotEqual(first, model.matchSeed)
    }

    // MARK: Career stats

    func testFinishingAMatchRecordsTheHumansResult() {
        let store = InMemoryStore()
        let model = AppModel(store: store)
        model.kickOff()

        let summary = summaryPlacingHuman(at: 1, conceded: 3, nations: model.lineup)
        model.finish(with: summary)

        XCTAssertEqual(model.screen, .results)
        XCTAssertEqual(model.stats.played, 1)
        XCTAssertEqual(model.stats.won, 1)
        XCTAssertEqual(model.stats.conceded, 3)
        XCTAssertEqual(model.stats.bestPlace, 1)
        XCTAssertEqual(store.stats, model.stats, "written through, not just held in memory")
    }

    func testALossIsRecordedWithoutAWin() {
        let model = AppModel(store: InMemoryStore())
        model.kickOff()
        model.finish(with: summaryPlacingHuman(at: 4, conceded: 6, nations: model.lineup))

        XCTAssertEqual(model.stats.played, 1)
        XCTAssertEqual(model.stats.won, 0)
        XCTAssertEqual(model.stats.bestPlace, 4)
    }

    func testBestPlaceOnlyImproves() {
        var stats = CareerStats()
        stats.record(place: 3, conceded: 6)
        stats.record(place: 5, conceded: 6)
        XCTAssertEqual(stats.bestPlace, 3)
        stats.record(place: 1, conceded: 2)
        XCTAssertEqual(stats.bestPlace, 1)
        XCTAssertEqual(stats.played, 3)
        XCTAssertEqual(stats.won, 1)
        XCTAssertEqual(stats.conceded, 14)
    }

    func testStatsSurviveEncoding() throws {
        var stats = CareerStats()
        stats.record(place: 2, conceded: 5)
        let data = try JSONEncoder().encode(stats)
        XCTAssertEqual(try JSONDecoder().decode(CareerStats.self, from: data), stats)
    }

    // MARK: Summary

    func testASummaryRanksBestFirstAndFindsTheHuman() {
        var engine = MatchFixture.engine()
        var brains = (0..<5).map { BotBrain(index: $0, difficulty: .normal, seed: 12) }
        for _ in 0..<MatchFixture.steps(forSeconds: 900) {
            let inputs = (0..<5).map { brains[$0].decide(state: engine.state, tuning: .default) }
            engine.step(inputs: inputs)
            if engine.state.isOver { break }
        }
        XCTAssertTrue(engine.state.isOver)

        let summary = MatchSummary(state: engine.state)
        XCTAssertEqual(summary.entries.count, 5)
        XCTAssertEqual(summary.entries.map(\.place), [1, 2, 3, 4, 5])
        XCTAssertEqual(summary.winner?.index, engine.state.winner)
        XCTAssertEqual(summary.human?.index, 0)
        XCTAssertEqual(summary.entries.filter(\.isHuman).count, 1)
        for entry in summary.entries {
            XCTAssertEqual(entry.nation, engine.state.players[entry.index].nation)
        }
    }

    private func summaryPlacingHuman(at place: Int, conceded: Int, nations: [Nation]) -> MatchSummary {
        var engine = MatchEngine(nations: nations, tuning: .default)
        // Reach a finished state by conceding through the engine's own rules rather than by
        // fabricating one, so the summary is built from a state the game could really produce.
        var brains = (0..<5).map { BotBrain(index: $0, difficulty: .normal, seed: 3) }
        for _ in 0..<MatchFixture.steps(forSeconds: 900) {
            let inputs = (0..<5).map { brains[$0].decide(state: engine.state, tuning: .default) }
            engine.step(inputs: inputs)
            if engine.state.isOver { break }
        }

        let real = MatchSummary(state: engine.state)
        // Re-label the places so the test can exercise a chosen outcome.
        var entries = real.entries
        if let humanIndex = entries.firstIndex(where: \.isHuman) {
            let human = entries.remove(at: humanIndex)
            entries.insert(MatchSummary.Entry(place: place, index: human.index,
                                              nation: human.nation, conceded: conceded,
                                              isHuman: true),
                           at: min(place - 1, entries.count))
        }
        return MatchSummary(entries: entries)
    }
}

/// The human's match ends when the human is out — see `docs/RULES.md` §6.
final class EarlyExitTests: XCTestCase {

    private let tuning = Tuning.default

    /// Plays until player 0 is knocked out, which is the moment the app stops the match.
    private func stateWhenHumanIsOut() -> (MatchState, Int)? {
        var engine = MatchFixture.engine(tuning: tuning)
        var brains = (0..<5).map { BotBrain(index: $0, difficulty: .normal, seed: 33) }

        for _ in 0..<MatchFixture.steps(forSeconds: 900) {
            let inputs = (0..<5).map { brains[$0].decide(state: engine.state, tuning: tuning) }
            for event in engine.step(inputs: inputs) {
                if case .eliminated(let player, let place) = event, player == 0 {
                    return (engine.state, place)
                }
            }
            if engine.state.isOver { return nil }
        }
        return nil
    }

    func testTheHumansPlaceIsHonouredWhileOthersAreStillIn() throws {
        guard let (state, place) = stateWhenHumanIsOut() else {
            throw XCTSkip("the human won this seed; nothing to check")
        }
        XCTAssertGreaterThan(state.aliveCount, 1, "several players are still standing")

        let summary = MatchSummary(state: state, humanPlace: place)
        XCTAssertEqual(summary.entries.count, 5)
        XCTAssertEqual(summary.entries.map(\.place), [1, 2, 3, 4, 5])
        XCTAssertEqual(Set(summary.entries.map(\.index)).count, 5)
        XCTAssertEqual(summary.human?.place, place,
                       "the human must be shown where they actually finished")
    }

    /// Survivors are ranked by how few they have let in, because at this point nobody has won
    /// yet and index order would be meaningless.
    func testSurvivorsAreRankedByGoalsAgainst() throws {
        guard let (state, _) = stateWhenHumanIsOut() else {
            throw XCTSkip("the human won this seed; nothing to check")
        }
        let survivors = state.standings.filter { state.players[$0].isAlive }
        let conceded = survivors.map { state.players[$0].conceded }
        XCTAssertEqual(conceded, conceded.sorted(), "best-placed survivor has let in fewest")
    }

    func testAFinishedMatchStillRanksTheWinnerFirst() {
        let outcome = BotMatch.play(seed: 21, capSeconds: 900)
        guard let winner = outcome.winner else { return XCTFail("match never finished") }
        let summary = MatchSummary(state: outcome.state)
        XCTAssertEqual(summary.winner?.index, winner)
        XCTAssertEqual(summary.entries.map(\.place), [1, 2, 3, 4, 5])
    }
}
