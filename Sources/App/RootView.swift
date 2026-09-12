import SwiftUI

/// The only place navigation happens. Each screen is handed exactly what it needs and reports
/// back by calling into `AppModel`, so no screen knows about any other.
struct RootView: View {
    @Bindable var model: AppModel

    var body: some View {
        ZStack {
            Theme.concreteBackdrop.ignoresSafeArea()

            switch model.screen {
            case .menu, .nationSelect, .results:
                // Screens arrive in M6. Until then the app boots straight into the pitch.
                MatchPlaceholderView()
            case .match:
                MatchPlaceholderView()
            }
        }
    }
}

/// M0 stand-in: proves the SwiftUI → SpriteKit bridge boots and the arena maths draws.
private struct MatchPlaceholderView: View {
    var body: some View {
        GameViewRepresentable()
            .ignoresSafeArea()
    }
}
