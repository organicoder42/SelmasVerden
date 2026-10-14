import SwiftUI

/// Her klædes figuren på: hver plads (hår, øjne, trøje, bukser, sko, strømper ...) er sin egen skuffe,
/// og hver del kan farves og justeres.
struct CharacterBuilderView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    let characterID: UUID

    @State private var slot: WearableSlot = .hair
    @State private var adjusting = false
    @State private var paintingLayer: CharacterLayer? = nil
    @State private var dragStartFit: AssetFit? = nil
    /// Den plads figuren faktisk vises i, så "Flyt" kan omsætte fingerens bevægelse til kroppens koordinater.
    @State private var figureSize: CGSize = .zero
    @State private var renaming = false
    @State private var newName = ""

    private var character: GameCharacter? { model.game.character(id: characterID) }

    var body: some View {
        ZStack {
            theme.paper.ignoresSafeArea()
            if let character {
                VStack(spacing: 0) {
                    TopBar(title: character.name) {
                        RoundIconButton(symbol: "pencil", label: "Navn") {
                            newName = character.name
                            renaming = true
                        }
                    }
                    HStack(spacing: 0) {
                        // Figuren
                        ZStack(alignment: .bottom) {
                            CharacterView(character: character, selectedSlot: adjusting ? slot : nil)
                                .background(
                                    GeometryReader { geo in
                                        Color.clear
                                            .onAppear { figureSize = geo.size }
                                            .onChange(of: geo.size) { _, s in figureSize = s }
                                    }
                                )
                                .padding(20)
                                .contentShape(Rectangle())
                                .gesture(adjustGesture(character))
                            HStack(spacing: 14) {
                                RoundIconButton(symbol: "arrow.up.and.down.and.arrow.left.and.right", label: "Flyt", active: adjusting) {
                                    adjusting.toggle()
                                }
                                .disabled(character.worn[slot] == nil)
                                RoundIconButton(symbol: "paintbrush", label: "Farv") {
                                    paintingLayer = character.layers.first { $0.slot == slot }
                                        ?? character.layers.first { $0.slot == nil }
                                }
                                RoundIconButton(symbol: "xmark", label: "Tag af") {
                                    var c = character
                                    c.remove(slot: slot)
                                    model.game.upsert(c)
                                }
                                .disabled(character.worn[slot] == nil)
                            }
                            .padding(.bottom, 12)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                        // Skufferne
                        VStack(spacing: 0) {
                            ScrollView(.horizontal) {
                                HStack(spacing: 10) {
                                    ForEach(WearableSlot.allCases) { s in
                                        SlotChip(slot: s, selected: slot == s, hasItem: character.worn[s] != nil) {
                                            slot = s
                                            adjusting = false
                                        }
                                    }
                                }
                                .padding(.horizontal, 16).padding(.vertical, 10)
                            }
                            Divider()
                            let items = model.library.assets(for: slot)
                            if items.isEmpty {
                                Spacer()
                                EmptyHint(title: "Ingen \(slot.danishName.lowercased()) endnu",
                                          text: "Tegn nogle, og læg dem ind under \"Nye tegninger\".")
                                Spacer()
                            } else {
                                ScrollView {
                                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 14)], spacing: 14) {
                                        ForEach(items) { asset in
                                            Button {
                                                var c = character
                                                if c.worn[slot]?.assetID == asset.id {
                                                    c.remove(slot: slot)
                                                } else {
                                                    c.wear(asset.id, in: slot)
                                                }
                                                model.game.upsert(c)
                                            } label: {
                                                AssetThumbnail(assetID: asset.id,
                                                               paint: character.worn[slot]?.assetID == asset.id ? character.worn[slot]!.paint : .none,
                                                               selected: character.worn[slot]?.assetID == asset.id, size: 110)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                    .padding(16)
                                }
                            }
                        }
                        .frame(width: 420)
                        .background(theme.card)
                    }
                }
            } else {
                EmptyHint(title: "Figuren findes ikke", text: "Den er måske blevet slettet.")
            }
        }
        .gameScreen()
        .sheet(item: $paintingLayer) { layer in
            if let character {
                PaintView(assetID: layer.assetID, paint: layer.slot.flatMap { character.worn[$0]?.paint } ?? character.bodyPaint) { newPaint in
                    var c = character
                    if let s = layer.slot {
                        c.worn[s]?.paint = newPaint
                    } else {
                        c.bodyPaint = newPaint
                    }
                    model.game.upsert(c)
                }
                .environment(model)
                .environment(\.theme, theme)
            }
        }
        .alert("Hvad skal figuren hedde?", isPresented: $renaming) {
            TextField("Navn", text: $newName)
            Button("Gem") {
                if var c = character, !newName.trimmingCharacters(in: .whitespaces).isEmpty {
                    c.name = newName
                    model.game.upsert(c)
                }
            }
            Button("Fortryd", role: .cancel) {}
        }
    }

    /// I "Flyt"-tilstand trækker man den valgte del rundt og kniber for at gøre den større/mindre.
    private func adjustGesture(_ character: GameCharacter) -> some Gesture {
        let drag = DragGesture(minimumDistance: 2)
            .onChanged { value in
                guard adjusting, let item = character.worn[slot] else { return }
                let body = model.library.asset(id: character.bodyAssetID)
                let asset = model.library.asset(id: item.assetID)
                let layer = CharacterLayer(slot: slot, assetID: item.assetID, paint: item.paint, fitOverride: item.fitOverride, zIndex: slot.zIndex)
                let start = dragStartFit ?? Rig.fit(for: layer, asset: asset, body: body)
                if dragStartFit == nil { dragStartFit = start }
                // Omsæt punkter til kroppens normaliserede koordinater ud fra den plads kroppen faktisk fylder.
                let bodyRect = CharacterView.bodyRect(in: figureSize, aspect: body?.aspectRatio ?? 0.5)
                guard bodyRect.width > 0, bodyRect.height > 0 else { return }
                var f = start
                f.center.x += value.translation.width / bodyRect.width
                f.center.y += value.translation.height / bodyRect.height
                var c = character
                c.worn[slot]?.fitOverride = f
                model.game.upsert(c)
            }
            .onEnded { _ in dragStartFit = nil }

        let pinch = MagnifyGesture()
            .onChanged { value in
                guard adjusting, let item = character.worn[slot] else { return }
                let body = model.library.asset(id: character.bodyAssetID)
                let asset = model.library.asset(id: item.assetID)
                let layer = CharacterLayer(slot: slot, assetID: item.assetID, paint: item.paint, fitOverride: item.fitOverride, zIndex: slot.zIndex)
                let start = dragStartFit ?? Rig.fit(for: layer, asset: asset, body: body)
                if dragStartFit == nil { dragStartFit = start }
                var f = start
                f.heightRatio = min(1.5, max(0.02, start.heightRatio * value.magnification))
                var c = character
                c.worn[slot]?.fitOverride = f
                model.game.upsert(c)
            }
            .onEnded { _ in dragStartFit = nil }

        return drag.simultaneously(with: pinch)
    }
}

struct SlotChip: View {
    @Environment(\.theme) private var theme
    let slot: WearableSlot
    let selected: Bool
    let hasItem: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if hasItem { Circle().fill(theme.selection).frame(width: 8, height: 8) }
                Text(slot.danishName).font(theme.font(15))
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(selected ? theme.selection.opacity(0.35) : theme.paper, in: Capsule())
            .overlay(Capsule().stroke(theme.ink.opacity(selected ? 1 : 0.35), lineWidth: 1.5))
            .foregroundStyle(theme.ink)
        }
        .buttonStyle(.plain)
    }
}
