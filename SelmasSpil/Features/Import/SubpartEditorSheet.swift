import SwiftUI

/// Når sorteringen siger "hel figur", vises dens forslag til dele som bokse oven på tegningen.
/// Den voksne kan trække boksene på plads, gøre dem større/mindre i hjørnet, ændre hvad de er,
/// tilføje og fjerne bokse - og først derefter dele figuren op.
struct SubpartEditorSheet: View {
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    @Binding var piece: ImportedPiece
    /// Kaldes når den voksne trykker "Del op". Selve opdelingen sker hos den der viser arket.
    let onSplit: () -> Void

    @State private var selected: Int?
    @State private var dragStart: NormalizedBox?

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Del figuren op").font(theme.font(26)).foregroundStyle(theme.ink)
                    Text("Træk boksene så de sidder rigtigt. Hjørnet gør dem større eller mindre.")
                        .font(theme.font(14, weight: .regular)).foregroundStyle(theme.inkSoft)
                }
                Spacer()
                Button("Luk") { dismiss() }.font(theme.font(18))
                Button {
                    onSplit()
                } label: {
                    Label("Del op", systemImage: "scissors")
                        .font(theme.font(20))
                        .padding(.horizontal, 18).padding(.vertical, 10)
                        .background(theme.selection, in: Capsule())
                        .foregroundStyle(theme.ink)
                }
                .buttonStyle(.plain)
                .disabled(piece.subparts.isEmpty)
            }
            .padding(20)

            HStack(spacing: 0) {
                GeometryReader { geo in
                    let rect = fitRect(aspect: piece.pixelSize.width / max(1, piece.pixelSize.height), in: geo.size)
                    ZStack {
                        CheckerBackground()
                        Image(decorative: piece.image, scale: 1)
                            .resizable()
                            .frame(width: rect.width, height: rect.height)
                            .position(x: rect.midX, y: rect.midY)
                        ForEach(piece.subparts.indices, id: \.self) { i in
                            boxView(i, in: rect)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { selected = nil }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius))
                .padding([.leading, .bottom], 20)

                sidebar
                    .frame(width: 300)
                    .background(theme.card)
            }
        }
        .background(theme.paper)
        .frame(minWidth: 800, minHeight: 560)
    }

    // MARK: - Bokse

    @ViewBuilder
    private func boxView(_ i: Int, in rect: CGRect) -> some View {
        let part = piece.subparts[i]
        let b = part.box
        let frame = CGRect(x: rect.minX + b.x * rect.width, y: rect.minY + b.y * rect.height,
                           width: b.width * rect.width, height: b.height * rect.height)
        let isSelected = selected == i

        ZStack(alignment: .topLeading) {
            Rectangle().fill(theme.selection.opacity(isSelected ? 0.2 : 0.06))
            Rectangle().stroke(isSelected ? theme.selection : theme.ink,
                               style: StrokeStyle(lineWidth: isSelected ? 3 : 1.5, dash: isSelected ? [] : [6, 4]))
            Text(part.category.danishName)
                .font(theme.font(12)).foregroundStyle(theme.paper)
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(isSelected ? theme.selection : theme.ink, in: Capsule())
                .offset(x: 2, y: -22)
        }
        .frame(width: frame.width, height: frame.height)
        .contentShape(Rectangle())
        .onTapGesture { selected = i }
        .gesture(
            DragGesture(minimumDistance: 1)
                .onChanged { v in
                    selected = i
                    let start = dragStart ?? b
                    if dragStart == nil { dragStart = start }
                    var nb = start
                    nb.x = min(1 - nb.width, max(0, start.x + v.translation.width / rect.width))
                    nb.y = min(1 - nb.height, max(0, start.y + v.translation.height / rect.height))
                    set(i, box: nb)
                }
                .onEnded { _ in dragStart = nil }
        )
        .overlay(alignment: .bottomTrailing) {
            if isSelected {
                Circle().fill(theme.selection)
                    .frame(width: 30, height: 30)
                    .overlay(Circle().stroke(theme.ink, lineWidth: 1.5))
                    .overlay(Image(systemName: "arrow.up.left.and.arrow.down.right").font(.system(size: 12, weight: .bold)).foregroundStyle(theme.ink))
                    .offset(x: 15, y: 15)
                    .gesture(
                        DragGesture(minimumDistance: 1)
                            .onChanged { v in
                                let start = dragStart ?? b
                                if dragStart == nil { dragStart = start }
                                var nb = start
                                nb.width = min(1 - nb.x, max(0.03, start.width + v.translation.width / rect.width))
                                nb.height = min(1 - nb.y, max(0.03, start.height + v.translation.height / rect.height))
                                set(i, box: nb)
                            }
                            .onEnded { _ in dragStart = nil }
                    )
            }
        }
        .position(x: frame.midX, y: frame.midY)
        .zIndex(isSelected ? 1 : 0)
    }

    private func set(_ i: Int, box: NormalizedBox) {
        guard piece.subparts.indices.contains(i) else { return }
        piece.subparts[i].box = box
    }

    // MARK: - Sidepanel

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let i = selected, piece.subparts.indices.contains(i) {
                Text("Valgt del").font(theme.font(18)).foregroundStyle(theme.ink)
                TextField("Navn", text: binding(i, \.name, default: ""))
                    .textFieldStyle(.roundedBorder).font(theme.font(16))
                Picker("Hvad er det?", selection: binding(i, \.category, default: .unknown)) {
                    ForEach(AssetGroup.allCases) { g in
                        Section(g.danishName) {
                            ForEach(g.categories) { c in Text(c.danishName).tag(c) }
                        }
                    }
                }
                .pickerStyle(.menu)
                .tint(theme.ink)
                Button(role: .destructive) {
                    selected = nil
                    piece.subparts.remove(at: i)
                } label: {
                    Label("Fjern boks", systemImage: "trash")
                }
                .font(theme.font(16))
            } else {
                Text("Tryk på en boks for at ændre, hvad den er.")
                    .font(theme.font(14, weight: .regular)).foregroundStyle(theme.inkSoft)
            }
            Divider()
            Button { addBox() } label: { Label("Ny boks", systemImage: "plus.rectangle") }
                .font(theme.font(16))
            Text("Kroppen beholder hele tegningen. Hver boks bliver sin egen del, der sidder samme sted på figuren og kan skiftes ud.")
                .font(theme.font(12, weight: .regular)).foregroundStyle(theme.inkSoft)
            Spacer()
        }
        .padding(20)
    }

    private func addBox() {
        piece.subparts.append(SubpartSuggestion(category: .top, name: "Ny del",
                                                box: NormalizedBox(x: 0.3, y: 0.35, width: 0.4, height: 0.2)))
        selected = piece.subparts.count - 1
    }

    /// Binding ind i en boks, der tåler at boksen forsvinder, mens feltet stadig vises.
    private func binding<T>(_ i: Int, _ keyPath: WritableKeyPath<SubpartSuggestion, T>, default d: T) -> Binding<T> {
        Binding(
            get: { piece.subparts.indices.contains(i) ? piece.subparts[i][keyPath: keyPath] : d },
            set: { if piece.subparts.indices.contains(i) { piece.subparts[i][keyPath: keyPath] = $0 } }
        )
    }

    private func fitRect(aspect: CGFloat, in size: CGSize) -> CGRect {
        var h = size.height * 0.9
        var w = h * aspect
        if w > size.width * 0.9 { w = size.width * 0.9; h = w / max(0.01, aspect) }
        return CGRect(x: (size.width - w) / 2, y: (size.height - h) / 2, width: w, height: h)
    }
}
