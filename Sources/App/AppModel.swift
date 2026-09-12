import Observation

/// Which screen is on show. `RootView` switches on this and nothing else navigates.
enum Screen: Equatable {
    case menu
    case nationSelect
    case match
    case results
}

/// App-wide screen state. Deliberately holds no simulation state — a match lives entirely
/// inside `GameScene`, which is built fresh on entry and torn down on exit, so nothing can
/// survive from one match into the next.
@Observable
final class AppModel {
    var screen: Screen = .menu

    func show(_ screen: Screen) {
        self.screen = screen
    }
}
