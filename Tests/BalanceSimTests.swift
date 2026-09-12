import XCTest
@testable import Svinjara

/// Story E5. Balance is measured, not guessed — this is a smaller version of the sweep
/// recorded in `docs/PHYSICS_AND_TUNING.md` §7, kept small enough to run on every build.
///
/// These are the assertions that caught, in order: a positional bias handing slot 0 a third
/// more goals against than its fair share, matches that never terminated at all, and a
/// difficulty scale that ran backwards.
final class BalanceSimTests: XCTestCase {

    private let tuning = Tuning.default
    private static let matches = 24

    /// Played once for the whole suite. Each match is a few thousand simulation steps, so
    /// replaying them per test would dominate the build.
    private static let sampled: [String: [BotMatch.Outcome]] = {
        var out: [String: [BotMatch.Outcome]] = [:]
        for difficulty in BotDifficulty.all {
            out[difficulty.id] = (0..<matches).map {
                BotMatch.play(seed: UInt64($0) &* 7919 &+ 13,
                              difficulties: [BotDifficulty](repeating: difficulty, count: 5),
                              tuning: .default,
                              capSeconds: 900)
            }
        }
        return out
    }()

    private func outcomes(difficulty: BotDifficulty) -> [BotMatch.Outcome] {
        Self.sampled[difficulty.id] ?? []
    }

    /// The one that must never regress: a match that cannot end is not a game.
    func testEveryMatchReachesAWinner() {
        for difficulty in BotDifficulty.all {
            let unfinished = outcomes(difficulty: difficulty).filter { !$0.finished }
            XCTAssertTrue(unfinished.isEmpty,
                          "\(unfinished.count)/\(Self.matches) \(difficulty.id) matches never ended")
        }
    }

    func testMatchLengthLandsInTheDesignBand() {
        let lengths = outcomes(difficulty: .normal).compactMap { $0.finished ? $0.seconds : nil }.sorted()
        XCTAssertFalse(lengths.isEmpty)

        let median = lengths[lengths.count / 2]
        XCTAssertGreaterThan(median, 120, "matches are over before anyone settles in")
        XCTAssertLessThan(median, 330, "median match has drifted past the 3–5 minute band")

        // And the tail stays sane, which is where stalls show up first.
        XCTAssertLessThan(lengths.last!, 600, "worst match ran far past the band")
    }

    func testScoringRateIsLively() {
        let finished = outcomes(difficulty: .normal).filter(\.finished)
        let perMinute = finished.map { Double($0.goals) / ($0.seconds / 60) }
        let mean = perMinute.reduce(0, +) / Double(perMinute.count)
        XCTAssertGreaterThan(mean, 5, "too few goals for a five-way scrap")
        XCTAssertLessThan(mean, 16, "so many goals that defending cannot matter")
    }

    /// Every slot must be as winnable as every other. Ball contacts were once applied in
    /// player-index order, which silently handed the last word on every contested ball to
    /// player 4 — and slot 0, the human's, won least of all.
    func testNoSlotIsFavouredByItsPosition() {
        let finished = outcomes(difficulty: .normal).filter(\.finished)
        var wins = [Int](repeating: 0, count: 5)
        for outcome in finished { wins[outcome.winner!] += 1 }

        let fairShare = Double(finished.count) / 5
        for (slot, count) in wins.enumerated() {
            XCTAssertLessThan(Double(count), fairShare * 2.2,
                              "slot \(slot) wins \(count) of \(finished.count); wins were \(wins)")
        }
    }

    /// Harder bots must actually be harder. This ran backwards for a long time: reaction
    /// latency was modelled as thinking frequency, which made fast bots attack more, and
    /// attacking is what loses matches.
    func testHarderBotsFinishHigherThanEasierOnes() {
        var placings: [String: (sum: Int, count: Int)] = [:]

        for match in 0..<20 {
            // Rotated, so a slot bias cannot masquerade as a difficulty effect.
            let base: [BotDifficulty] = [.hard, .hard, .normal, .easy, .easy]
            let shift = match % 5
            let lineup = (0..<5).map { base[($0 + shift) % 5] }

            var engine = MatchFixture.engine(tuning: tuning)
            var brains = (0..<5).map { BotBrain(index: $0, difficulty: lineup[$0], seed: UInt64(match) &* 104_729 &+ 7) }
            for _ in 0..<MatchFixture.steps(forSeconds: 900) {
                let inputs = (0..<5).map { brains[$0].decide(state: engine.state, tuning: tuning) }
                engine.step(inputs: inputs)
                if engine.state.isOver { break }
            }

            let order = engine.state.players.sorted {
                ($0.isAlive ? 0 : 1, $0.conceded) < ($1.isAlive ? 0 : 1, $1.conceded)
            }
            for (place, player) in order.enumerated() {
                var entry = placings[lineup[player.index].id] ?? (0, 0)
                entry.sum += place + 1
                entry.count += 1
                placings[lineup[player.index].id] = entry
            }
        }

        func meanPlace(_ id: String) -> Double {
            guard let entry = placings[id], entry.count > 0 else { return .nan }
            return Double(entry.sum) / Double(entry.count)
        }

        let hard = meanPlace("hard"), easy = meanPlace("easy")
        XCTAssertLessThan(hard, easy,
                          "hard finishes \(hard)th on average, easy \(easy)th — the scale is inverted")
    }

    /// A restart must not simply hand somebody a goal.
    ///
    /// With the home spots at 0.55 R every player stood 4.3 m in front of their own mouth, so
    /// all five goals were undefended at the instant of every kickoff and 19% of all goals
    /// arrived within two seconds of a restart — you would barely see the ball touch the
    /// centre spot before it was in somebody's net again.
    func testNoGoalArrivesImmediatelyAfterARestart() {
        var tooSoon = 0
        var measured = 0

        for seed in 0..<12 {
            var engine = MatchFixture.engine(tuning: tuning)
            var brains = (0..<5).map { BotBrain(index: $0, difficulty: .normal, seed: UInt64(seed) &* 7919 &+ 13) }
            var sinceRestart: Double? = 0   // the opening kickoff counts

            for _ in 0..<MatchFixture.steps(forSeconds: 900) {
                let inputs = (0..<5).map { brains[$0].decide(state: engine.state, tuning: tuning) }
                for event in engine.step(inputs: inputs) {
                    switch event {
                    case .conceded:
                        if let gap = sinceRestart {
                            measured += 1
                            if gap < 1.5 { tooSoon += 1 }
                        }
                        sinceRestart = nil
                    case .resumed:
                        sinceRestart = 0
                    default:
                        break
                    }
                }
                if sinceRestart != nil { sinceRestart! += tuning.fixedStep }
                if engine.state.isOver { break }
            }
        }

        XCTAssertGreaterThan(measured, 100, "not enough restarts to judge")
        XCTAssertLessThan(Double(tooSoon) / Double(measured), 0.02,
                          "\(tooSoon) of \(measured) goals came within 1.5 s of a restart")
    }

    /// The other half of the same property: everyone starts guarding their own line.
    func testEveryoneRestartsOnTheirOwnLine() {
        let arena = ArenaGeometry(tuning: tuning)
        for goal in 0..<arena.goalCount {
            let home = arena.homeSpot(of: goal, fraction: tuning.homeSpotFraction)
            let distanceToOwnLine = arena.radius - home.length
            XCTAssertLessThan(distanceToOwnLine, 2.0,
                              "player \(goal) restarts \(distanceToOwnLine) m off their own line")
            XCTAssertGreaterThan(distanceToOwnLine, tuning.playerRadius,
                                 "and not standing in the goal itself")
        }
    }

    /// Progress is a rule, not a hope. A ball pinned against the paint cannot be struck along
    /// the wall, so without this the match can simply stop.
    func testAPinnedBallIsReturnedToTheCentre() {
        var engine = MatchFixture.engine(tuning: tuning)
        let idle = [PlayerInput](repeating: .idle, count: 5)

        // Nobody touches it; the ball sits exactly where it started.
        var reset = false
        for _ in 0..<MatchFixture.steps(forSeconds: tuning.stagnationTimeout + 0.2) {
            if engine.step(inputs: idle).contains(.ballReset) { reset = true; break }
        }
        XCTAssertTrue(reset, "the stagnation rule never fired")
    }

    func testAMovingBallNeverTriggersTheStagnationRule() {
        var engine = MatchFixture.engine(tuning: tuning)
        var brains = (0..<5).map { BotBrain(index: $0, difficulty: .normal, seed: 4) }

        var resets = 0
        var goals = 0
        for _ in 0..<MatchFixture.steps(forSeconds: 240) {
            let inputs = (0..<5).map { brains[$0].decide(state: engine.state, tuning: tuning) }
            for event in engine.step(inputs: inputs) {
                if event == .ballReset { resets += 1 }
                if event.isConcede { goals += 1 }
            }
            if engine.state.isOver { break }
        }
        XCTAssertGreaterThan(goals, 5, "this test is only meaningful if a real match happened")
        XCTAssertLessThan(resets, goals / 3, "the rule is firing during ordinary play")
    }
}
