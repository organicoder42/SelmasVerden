import SwiftUI

@main
struct SelmasSpilApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .environment(\.theme, model.theme)
                .onAppear { model.start() }
        }
    }
}
