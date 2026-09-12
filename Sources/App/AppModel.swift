import Observation

/// Which screen is on show. `RootView` switches on this and nothing else navigates.
enum Screen: Equatable {
    case menu
    case nationSelect
    case match
    case results
}

/// App-wide state: which screen, who the player picked, and what the last match did.
///
/// Deliberately holds no simulation state — a match lives entirely inside `GameScene`, which
/// is built fresh on entry and torn down on exit, so nothing can survive from one match into
/// the next.
@Observable
final class AppModel {

    private let store: LocalStore

    var screen: Screen = .menu
    var chosenNation: Nation
    var difficulty: BotDifficulty
    var soundEnabled: Bool {
        didSet { store.soundEnabled = soundEnabled }
    }

    private(set) var lineup: [Nation] = []
    private(set) var matchSeed: UInt64 = 0
    private(set) var summary: MatchSummary?
    private(set) var stats: CareerStats

    init(store: LocalStore = UserDefaultsStore()) {
        self.store = store
        self.chosenNation = store.lastNationID.flatMap(NationCatalog.nation(id:))
            ?? NationCatalog.all[0]
        self.difficulty = BotDifficulty.named(store.difficultyID ?? BotDifficulty.normal.id)
        self.soundEnabled = store.soundEnabled
        self.stats = store.stats
    }

    func show(_ screen: Screen) {
        self.screen = screen
    }

    func choose(_ nation: Nation) {
        chosenNation = nation
        store.lastNationID = nation.id
    }

    func choose(_ difficulty: BotDifficulty) {
        self.difficulty = difficulty
        store.difficultyID = difficulty.id
    }

    /// Deals the opponents and starts a match. The seed is drawn here rather than inside the
    /// simulation, so every match is different while any one of them stays reproducible.
    func kickOff() {
        matchSeed = UInt64.random(in: 0...UInt64.max)
        var rng = SeededRandom(seed: matchSeed)
        lineup = [chosenNation] + NationCatalog.dealOpponents(count: 4,
                                                              avoiding: chosenNation,
                                                              rng: &rng)
        summary = nil
        screen = .match
    }

    func finish(with summary: MatchSummary) {
        self.summary = summary
        if let human = summary.human {
            stats.record(place: human.place, conceded: human.conceded)
            store.stats = stats
        }
        screen = .results
    }
}
