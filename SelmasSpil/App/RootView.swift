import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var theme
    @State private var path: [Route] = []

    var body: some View {
        NavigationStack(path: $path) {
            HomeView(path: $path)
                .navigationDestination(for: Route.self) { route in
                    destination(for: route)
                }
        }
        .tint(theme.ink)
        .background(theme.paper)
    }

    @ViewBuilder
    private func destination(for route: Route) -> some View {
        switch route {
        case .world:
            WorldView(path: $path)
        case .house(let id):
            HouseView(path: $path, houseID: id)
        case .characters:
            CharacterListView(path: $path)
        case .characterBuilder(let id):
            CharacterBuilderView(characterID: id)
        case .parents:
            ParentGateView(path: $path)
        case .importDrawing:
            ImportFlowView(path: $path)
        case .library:
            LibraryView()
        case .settings:
            ParentSettingsView()
        }
    }
}
