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

    /// - Parameter humanPlace: the place the human actually finished in, when the match is
    ///   being summarised early because *they* were knocked out. The standings cannot work
    ///   this out alone: several players may still be in, and which of them eventually wins is
    ///   not yet decided — nor does it matter to the player, who is out either way.
    init(state: MatchState, humanIndex: Int = 0, humanPlace: Int? = nil) {
        var order = state.standings
        if let humanPlace, let current = order.firstIndex(of: humanIndex) {
            order.remove(at: current)
            order.insert(humanIndex, at: min(humanPlace - 1, order.count))
        }
        entries = order.enumerated().map { place, index in
            Entry(place: place + 1,
                  index: index,
                  nation: state.players[index].nation,
                  conceded: state.players[index].conceded,
                  isHuman: index == humanIndex)
        }
    }
}
