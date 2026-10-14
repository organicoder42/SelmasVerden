import SwiftUI

/// Skuffen i bunden af scenen med ting man kan stille ind, inddelt i kategorier, plus figurerne.
struct ItemDrawerView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var theme
    let room: Room
    let onPick: (DrawingAsset) -> Void
    let onPickCharacter: (GameCharacter) -> Void
    @State private var category: AssetCategory?

    private var categories: [AssetCategory] {
        room.kind.allowedCategories.filter { !model.library.assets(in: $0).isEmpty }
    }

    var body: some View {
        VStack(spacing: 6) {
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    chip(title: "Figurer", selected: category == nil) { category = nil }
                    ForEach(categories) { c in
                        chip(title: c.danishName, selected: category == c) { category = c }
                    }
                }
                .padding(.horizontal, 8)
            }
            ScrollView(.horizontal) {
                HStack(spacing: 12) {
                    if let category {
                        ForEach(model.library.assets(in: category)) { a in
                            Button { onPick(a) } label: { AssetThumbnail(assetID: a.id, size: 86) }.buttonStyle(.plain)
                        }
                    } else {
                        if model.game.characters.isEmpty {
                            Text("Lav en figur under \"Figurer\" - så kan den stilles ind her.")
                                .font(theme.font(14, weight: .regular)).foregroundStyle(theme.inkSoft).padding(.horizontal, 12)
                        }
                        ForEach(model.game.characters) { c in
                            Button { onPickCharacter(c) } label: {
                                CharacterView(character: c).frame(width: 70, height: 86)
                                    .padding(6)
                                    .background(theme.card, in: RoundedRectangle(cornerRadius: theme.cornerRadius * 0.6))
                                    .overlay(RoundedRectangle(cornerRadius: theme.cornerRadius * 0.6).stroke(theme.ink.opacity(0.35), lineWidth: 1.5))
                            }.buttonStyle(.plain)
                        }
                    }
                    if category != nil && categories.isEmpty {
                        Text("Ingen ting at stille ind endnu.").font(theme.font(14, weight: .regular)).foregroundStyle(theme.inkSoft)
                    }
                }
                .padding(.horizontal, 8).padding(.bottom, 6)
            }
        }
        .background(theme.card, in: RoundedRectangle(cornerRadius: theme.cornerRadius))
        .onAppear { if category == nil, !model.game.characters.isEmpty || categories.isEmpty { category = nil } else { category = categories.first } }
    }

    private func chip(title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(theme.font(14))
                .padding(.horizontal, 12).padding(.vertical, 7)
                .background(selected ? theme.selection.opacity(0.4) : theme.paper, in: Capsule())
                .overlay(Capsule().stroke(theme.ink.opacity(selected ? 1 : 0.3), lineWidth: 1.5))
                .foregroundStyle(theme.ink)
        }
        .buttonStyle(.plain)
    }
}
