import SwiftUI

/// The only place navigation happens. Each screen is handed exactly what it needs and reports
/// back by calling into `AppModel`, so no screen knows about any other.
struct RootView: View {
    @Bindable var model: AppModel

    var body: some View {
        ZStack {
            Theme.concreteBackdrop.ignoresSafeArea()

            switch model.screen {
            case .menu:
                MenuView(model: model)

            case .nationSelect:
                NationSelectView(model: model)

            case .match:
                GameViewRepresentable(lineup: model.lineup,
                                      difficulty: model.difficulty,
                                      seed: model.matchSeed,
                                      onFinish: model.finish)
                    .ignoresSafeArea()
                    // A fresh scene per match: nothing can survive from one into the next.
                    .id(model.matchSeed)

            case .results:
                if let summary = model.summary {
                    ResultsView(model: model, summary: summary)
                } else {
                    MenuView(model: model)
                }
            }
        }
    }
}
