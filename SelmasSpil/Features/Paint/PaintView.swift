import SwiftUI

/// Malerspanden: tryk på et område af tegningen og det fyldes med en farve eller et mønster.
/// Mønstrene er selv tegninger (kategori "Mønster"), så Selma kan tegne sine egne.
struct PaintView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    let assetID: UUID
    @State var paint: PaintState
    let onSave: (PaintState) -> Void

    @State private var tool: Tool = .color(RGBA(hex: "#FF5A5F")!)
    @State private var patternScale: CGFloat = 0.12

    enum Tool: Equatable {
        case color(RGBA)
        case pattern(UUID)
    }

    init(assetID: UUID, paint: PaintState, onSave: @escaping (PaintState) -> Void) {
        self.assetID = assetID
        self._paint = State(initialValue: paint)
        self.onSave = onSave
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                Text("Farv og pynt").font(theme.font(26)).foregroundStyle(theme.ink)
                Spacer()
                RoundIconButton(symbol: "arrow.uturn.backward", label: "Fortryd") { paint.undo() }
                    .disabled(paint.isEmpty)
                RoundIconButton(symbol: "trash", label: "Start forfra") { paint = .none }
                    .disabled(paint.isEmpty)
                RoundIconButton(symbol: "checkmark", label: "Færdig", active: true) {
                    onSave(paint)
                    dismiss()
                }
            }
            .padding(20)

            HStack(spacing: 0) {
                // Tegningen
                GeometryReader { geo in
                    if let asset = model.library.asset(id: assetID),
                       let img = model.renderer.image(for: assetID, paint: paint) {
                        let rect = fitRect(aspect: asset.aspectRatio, in: geo.size)
                        Image(decorative: img, scale: 1)
                            .resizable()
                            .interpolation(.high)
                            .frame(width: rect.width, height: rect.height)
                            .position(x: rect.midX, y: rect.midY)
                            .onTapGesture(coordinateSpace: .local) { location in
                                let nx = (location.x - rect.minX) / rect.width
                                let ny = (location.y - rect.minY) / rect.height
                                guard nx >= 0, nx <= 1, ny >= 0, ny <= 1 else { return }
                                let style: FillStyle
                                switch tool {
                                case .color(let c): style = .color(c)
                                case .pattern(let id): style = .pattern(assetID: id, scale: patternScale, background: nil)
                                }
                                paint.add(RegionFill(seed: CGPoint(x: nx, y: ny), style: style))
                            }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(theme.paper)

                // Farver og mønstre
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        Text("Farver").font(theme.font(18)).foregroundStyle(theme.ink)
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 52), spacing: 10)], spacing: 10) {
                            ForEach(theme.paintPalette, id: \.hex) { c in
                                Button { tool = .color(c) } label: {
                                    Circle().fill(Color(c))
                                        .frame(width: 52, height: 52)
                                        .overlay(Circle().stroke(theme.ink, lineWidth: tool == .color(c) ? 4 : 1.5))
                                }.buttonStyle(.plain)
                            }
                        }
                        Text("Hudfarver").font(theme.font(18)).foregroundStyle(theme.ink)
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 52), spacing: 10)], spacing: 10) {
                            ForEach(Theme.skinTones, id: \.hex) { c in
                                Button { tool = .color(c) } label: {
                                    Circle().fill(Color(c))
                                        .frame(width: 52, height: 52)
                                        .overlay(Circle().stroke(theme.ink, lineWidth: tool == .color(c) ? 4 : 1.5))
                                }.buttonStyle(.plain)
                            }
                        }
                        Text("Mønstre").font(theme.font(18)).foregroundStyle(theme.ink)
                        if model.library.patterns.isEmpty {
                            Text("Tegn et mønster (prikker, striber, hjerter) på et stykke papir og læg det ind som \"Mønster\".")
                                .font(theme.font(14, weight: .regular)).foregroundStyle(theme.inkSoft)
                        } else {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 72), spacing: 10)], spacing: 10) {
                                ForEach(model.library.patterns) { p in
                                    Button { tool = .pattern(p.id) } label: {
                                        AssetThumbnail(assetID: p.id, selected: tool == .pattern(p.id), size: 72)
                                    }.buttonStyle(.plain)
                                }
                            }
                            HStack {
                                Image(systemName: "minus.magnifyingglass")
                                Slider(value: $patternScale, in: 0.04...0.4)
                                Image(systemName: "plus.magnifyingglass")
                            }
                            .foregroundStyle(theme.ink)
                        }
                    }
                    .padding(20)
                }
                .frame(width: 320)
                .background(theme.card)
            }
        }
        .background(theme.paper)
        .frame(minWidth: 700, minHeight: 500)
    }

    private func fitRect(aspect: CGFloat, in size: CGSize) -> CGRect {
        var h = size.height * 0.9
        var w = h * aspect
        if w > size.width * 0.9 { w = size.width * 0.9; h = w / max(0.01, aspect) }
        return CGRect(x: (size.width - w) / 2, y: (size.height - h) / 2, width: w, height: h)
    }
}
