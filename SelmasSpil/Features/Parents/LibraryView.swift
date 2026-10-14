import SwiftUI

/// Oversigt over alle tegninger i spillet, inddelt i kategorier. Her kan man omdøbe, flytte til
/// en anden kategori eller slette dem man selv har lagt ind.
struct LibraryView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    @State private var group: AssetGroup = .clothing
    @State private var editing: DrawingAsset?

    var body: some View {
        ZStack {
            theme.paper.ignoresSafeArea()
            VStack(spacing: 0) {
                TopBar(title: "Mine tegninger") { EmptyView() }
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(AssetGroup.allCases) { g in
                            let n = model.library.assets(in: g.categories).count
                            Button {
                                group = g
                            } label: {
                                Text("\(g.danishName) (\(n))").font(theme.font(15))
                                    .padding(.horizontal, 14).padding(.vertical, 9)
                                    .background(group == g ? theme.selection.opacity(0.4) : theme.card, in: Capsule())
                                    .overlay(Capsule().stroke(theme.ink.opacity(group == g ? 1 : 0.3), lineWidth: 1.5))
                                    .foregroundStyle(theme.ink)
                            }.buttonStyle(.plain)
                        }
                    }.padding(.horizontal, 20).padding(.vertical, 8)
                }
                let items = model.library.assets(in: group.categories)
                if items.isEmpty {
                    Spacer()
                    EmptyHint(title: "Ingenting her endnu", text: "Tegn noget og læg det ind under \"Nye tegninger\".")
                    Spacer()
                } else {
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 16)], spacing: 16) {
                            ForEach(items) { a in
                                Button { editing = a } label: {
                                    VStack(spacing: 6) {
                                        AssetThumbnail(assetID: a.id, size: 130)
                                        Text(a.name).font(theme.font(14)).foregroundStyle(theme.ink).lineLimit(1)
                                        Text(a.category.danishName).font(theme.font(11, weight: .regular)).foregroundStyle(theme.inkSoft)
                                    }
                                }.buttonStyle(.plain)
                            }
                        }.padding(20)
                    }
                }
            }
        }
        .gameScreen()
        .sheet(item: $editing) { asset in
            AssetEditSheet(asset: asset).environment(model).environment(\.theme, theme)
        }
    }
}

struct AssetEditSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    @State var asset: DrawingAsset
    @State private var error: String?

    var body: some View {
        VStack(spacing: 18) {
            AssetThumbnail(assetID: asset.id, size: 220)
            TextField("Navn", text: $asset.name).textFieldStyle(.roundedBorder).font(theme.font(18)).frame(maxWidth: 360)
            Picker("Kategori", selection: $asset.category) {
                ForEach(AssetGroup.allCases) { g in
                    Section(g.danishName) {
                        ForEach(g.categories) { c in Text(c.danishName).tag(c) }
                    }
                }
            }
            .pickerStyle(.menu)
            if asset.source == .bundled {
                Text("Denne tegning følger med spillet og kan ikke ændres her.").font(theme.font(13, weight: .regular)).foregroundStyle(theme.inkSoft)
            }
            if let error { Text(error).foregroundStyle(.red) }
            HStack(spacing: 20) {
                if asset.source == .imported {
                    Button("Slet", role: .destructive) {
                        do { try model.library.delete(asset); model.renderer.invalidate(); dismiss() } catch { self.error = error.localizedDescription }
                    }
                    Button("Gem") {
                        do { try model.library.update(asset); dismiss() } catch { self.error = error.localizedDescription }
                    }
                }
                Button("Luk") { dismiss() }
            }
            .font(theme.font(20))
        }
        .padding(28)
        .frame(minWidth: 480, minHeight: 440)
        .background(theme.paper)
    }
}
