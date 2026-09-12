import Foundation

/// What the results screen needs, lifted out of the final `MatchState` so the SwiftUI layer
/// never has to know about the simulation's types.
struct MatchSummary: Equatable {

    struct Entry: Equatable {
        let place: Int
        let index: Int
        let nation: Nation
        let conceded: Int
        let isHuman: Bool
    }

    /// Best first.
    let entries: [Entry]

    var winner: Entry? { entries.first }
    var human: Entry? { entries.first { $0.isHuman } }

    init(entries: [Entry]) {
        self.entries = entries
    }

    init(state: MatchState, humanIndex: Int = 0) {
        entries = state.standings.enumerated().map { place, index in
            Entry(place: place + 1,
                  index: index,
                  nation: state.players[index].nation,
                  conceded: state.players[index].conceded,
                  isHuman: index == humanIndex)
        }
    }
}
