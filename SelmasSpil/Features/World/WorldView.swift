import SwiftUI

/// Verdenen: gaden med husene. Tryk på et hus for at gå ind. Figurer kan også stilles på gaden.
struct WorldView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var theme
    @Binding var path: [Route]
    @State private var showStreet = false

    var body: some View {
        ZStack {
            theme.paper.ignoresSafeArea()
            VStack(spacing: 0) {
                TopBar(title: "Verden", onBack: { _ = path.popLast() }) {
                    RoundIconButton(symbol: "road.lanes", label: "Gaden", active: showStreet) { showStreet.toggle() }
                    RoundIconButton(symbol: "plus", label: "Nyt hus") {
                        _ = model.newHouse(named: "Hus \(model.game.houses.count + 1)")
                    }
                }
                if showStreet {
                    RoomSceneView(roomID: model.game.street.id, houseID: nil)
                        .padding(16)
                } else {
                    ScrollView(.horizontal) {
                        HStack(alignment: .bottom, spacing: 40) {
                            ForEach(model.game.houses) { house in
                                Button { path.append(.house(house.id)) } label: {
                                    VStack(spacing: 10) {
                                        if let f = house.facadeAssetID,
                                           let img = model.renderer.image(for: f, paint: house.facadePaint) {
                                            Image(decorative: img, scale: 1).resizable().scaledToFit().frame(height: 360)
                                        } else {
                                            PlaceholderHouse().frame(width: 300, height: 360)
                                        }
                                        Text(house.name).font(theme.font(22)).foregroundStyle(theme.ink)
                                    }
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button(role: .destructive) { model.game.deleteHouse(id: house.id) } label: {
                                        Label("Slet hus", systemImage: "trash")
                                    }
                                }
                            }
                        }
                        .padding(40)
                    }
                    .frame(maxHeight: .infinity)
                }
            }
        }
        .gameScreen()
    }
}

/// Indtil Selma har tegnet et hus set udefra, vises en neutral kontur.
struct PlaceholderHouse: View {
    @Environment(\.theme) private var theme
    var body: some View {
        VStack(spacing: 0) {
            Triangle().stroke(theme.ink, style: StrokeStyle(lineWidth: theme.strokeWidth, lineJoin: .round))
                .frame(height: 110)
            RoundedRectangle(cornerRadius: 4).stroke(theme.ink, lineWidth: theme.strokeWidth)
                .overlay(
                    VStack {
                        Text("Tegn et hus!").font(theme.font(18)).foregroundStyle(theme.inkSoft)
                    }
                )
        }
    }
}

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}
