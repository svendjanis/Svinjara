import SwiftUI

@main
struct SvinjaraApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView(model: model)
                .statusBarHidden()
                .persistentSystemOverlays(.hidden)
        }
    }
}
