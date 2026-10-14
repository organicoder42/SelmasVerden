import SwiftUI

struct HomeView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var theme
    @Binding var path: [Route]

    var body: some View {
        ZStack {
            theme.paper.ignoresSafeArea()
            VStack(spacing: 28) {
                Text("Selmas Spil")
                    .font(theme.font(44, weight: .bold))
                    .foregroundStyle(theme.ink)
                    .padding(.top, 24)

                HStack(spacing: 24) {
                    BigButton(title: "Leg", symbol: "house.and.flag") { path.append(.world) }
                    BigButton(title: "Figurer", symbol: "person.2") { path.append(.characters) }
                }
                HStack(spacing: 24) {
                    BigButton(title: "Nye tegninger", symbol: "camera") { path.append(.parents) }
                    BigButton(title: "Mine tegninger", symbol: "square.grid.2x2") { path.append(.library) }
                }

                if model.library.assets.isEmpty {
                    Text("Der er ikke lagt tegninger ind endnu. Tryk på \"Nye tegninger\" og tag et billede af en tegning.")
                        .font(theme.font(16, weight: .regular))
                        .foregroundStyle(theme.inkSoft)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                Spacer()
                if model.theme.seed.isNeutral {
                    Text("Stilen er stadig neutral - den bliver lavet af Selmas første tegninger.")
                        .font(theme.font(12, weight: .regular)).foregroundStyle(theme.inkSoft)
                }
            }
            .padding(.horizontal, 48)
            .frame(maxWidth: 900)
        }
        .gameScreen()
    }
}
