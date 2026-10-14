import SwiftUI

struct CharacterListView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var theme
    @Binding var path: [Route]
    @State private var showBodyPicker = false

    var body: some View {
        ZStack {
            theme.paper.ignoresSafeArea()
            VStack(spacing: 0) {
                TopBar(title: "Figurer", onBack: { _ = path.popLast() }) {
                    RoundIconButton(symbol: "plus", label: "Ny figur") {
                        showBodyPicker = true
                    }
                    .disabled(!model.library.canBuildCharacters)
                }
                if model.game.characters.isEmpty {
                    Spacer()
                    if model.library.canBuildCharacters {
                        EmptyHint(title: "Ingen figurer endnu", text: "Tryk på + for at lave den første figur.", symbol: "person.badge.plus")
                    } else {
                        EmptyHint(title: "Der mangler en krop", text: "Tegn en figur uden tøj, tag et billede af den under \"Nye tegninger\", og vælg kategorien Krop.", symbol: "figure.stand")
                    }
                    Spacer()
                } else {
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 20)], spacing: 20) {
                            ForEach(model.game.characters) { c in
                                Button {
                                    path.append(.characterBuilder(c.id))
                                } label: {
                                    VStack {
                                        CharacterView(character: c)
                                            .frame(height: 220)
                                        Text(c.name).font(theme.font(20)).foregroundStyle(theme.ink)
                                    }
                                    .padding(12)
                                    .background(theme.card, in: RoundedRectangle(cornerRadius: theme.cornerRadius))
                                    .overlay(RoundedRectangle(cornerRadius: theme.cornerRadius).stroke(theme.ink.opacity(0.4), lineWidth: 1.5))
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button(role: .destructive) {
                                        model.game.deleteCharacter(id: c.id)
                                    } label: { Label("Slet figur", systemImage: "trash") }
                                }
                            }
                        }
                        .padding(24)
                    }
                }
            }
        }
        .gameScreen()
        .sheet(isPresented: $showBodyPicker) {
            BodyPickerSheet { bodyID in
                let c = model.newCharacter(named: "Figur \(model.game.characters.count + 1)", bodyAssetID: bodyID)
                showBodyPicker = false
                path.append(.characterBuilder(c.id))
            }
            .environment(model)
            .environment(\.theme, theme)
        }
    }
}

/// Vælg hvilken krop den nye figur skal have.
struct BodyPickerSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    let onPick: (UUID) -> Void

    var body: some View {
        VStack(spacing: 20) {
            Text("Vælg en krop").font(theme.font(28)).foregroundStyle(theme.ink).padding(.top, 20)
            ScrollView(.horizontal) {
                HStack(spacing: 20) {
                    ForEach(model.library.bodies) { b in
                        Button { onPick(b.id) } label: {
                            AssetThumbnail(assetID: b.id, size: 200)
                        }.buttonStyle(.plain)
                    }
                }.padding(24)
            }
            Button("Luk") { dismiss() }.font(theme.font(20)).padding(.bottom, 20)
        }
        .frame(minWidth: 500, minHeight: 360)
        .background(theme.paper)
    }
}
