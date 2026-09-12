import Foundation

/// What the game remembers between launches. There is no database and nothing leaves the
/// device — this is the whole of persistence.
struct CareerStats: Equatable, Codable {
    var played = 0
    var won = 0
    var conceded = 0
    /// Best finishing position, 1 being a win. Zero means nothing played yet.
    var bestPlace = 0

    mutating func record(place: Int, conceded: Int) {
        played += 1
        self.conceded += conceded
        if place == 1 { won += 1 }
        if bestPlace == 0 || place < bestPlace { bestPlace = place }
    }
}

/// Behind a protocol so tests use an in-memory implementation and never touch the real
/// defaults — a test suite that writes to `UserDefaults.standard` quietly changes the
/// behaviour of the app on the machine that ran it.
protocol LocalStore: AnyObject {
    var lastNationID: String? { get set }
    var difficultyID: String? { get set }
    var soundEnabled: Bool { get set }
    var stats: CareerStats { get set }
}

final class UserDefaultsStore: LocalStore {

    private enum Key {
        static let nation = "svinjara.nation"
        static let difficulty = "svinjara.difficulty"
        static let sound = "svinjara.sound"
        static let stats = "svinjara.stats"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        // Sound defaults to on, which `bool(forKey:)` cannot express on a first run.
        if defaults.object(forKey: Key.sound) == nil {
            defaults.set(true, forKey: Key.sound)
        }
    }

    var lastNationID: String? {
        get { defaults.string(forKey: Key.nation) }
        set { defaults.set(newValue, forKey: Key.nation) }
    }

    var difficultyID: String? {
        get { defaults.string(forKey: Key.difficulty) }
        set { defaults.set(newValue, forKey: Key.difficulty) }
    }

    var soundEnabled: Bool {
        get { defaults.bool(forKey: Key.sound) }
        set { defaults.set(newValue, forKey: Key.sound) }
    }

    var stats: CareerStats {
        get {
            guard let data = defaults.data(forKey: Key.stats),
                  let decoded = try? JSONDecoder().decode(CareerStats.self, from: data) else {
                return CareerStats()
            }
            return decoded
        }
        set {
            guard let data = try? JSONEncoder().encode(newValue) else { return }
            defaults.set(data, forKey: Key.stats)
        }
    }
}
