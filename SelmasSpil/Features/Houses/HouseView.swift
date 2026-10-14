import SwiftUI

/// Et hus: en lodret stak af rum (tagterrasse øverst, haven nederst). Man vælger et rum i siden
/// og indretter det i scenen.
struct HouseView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var theme
    @Binding var path: [Route]
    let houseID: UUID
    @State private var selectedRoomID: UUID?
    @State private var showFacadePicker = false

    private var house: House? { model.game.house(id: houseID) }

    var body: some View {
        ZStack {
            theme.paper.ignoresSafeArea()
            if let house {
                VStack(spacing: 0) {
                    TopBar(title: house.name, onBack: { _ = path.popLast() }) {
                        RoundIconButton(symbol: "house", label: "Udseende") { showFacadePicker = true }
                        RoundIconButton(symbol: "plus.rectangle.on.rectangle", label: "Ny etage") {
                            var h = house
                            let indoorLevels = h.rooms.filter { $0.kind == .indoor }.map(\.level)
                            let newLevel = (indoorLevels.max() ?? 0) + 1
                            // Skub taget op
                            for i in h.rooms.indices where h.rooms[i].kind == .roofTerrace { h.rooms[i].level = newLevel + 1 }
                            h.rooms.append(Room(name: "Etage \(newLevel)", kind: .indoor, level: newLevel))
                            model.game.upsert(h)
                        }
                    }
                    HStack(spacing: 0) {
                        // Etage-vælger
                        VStack(spacing: 10) {
                            ForEach(house.roomsTopDown) { room in
                                Button {
                                    selectedRoomID = room.id
                                } label: {
                                    VStack(spacing: 4) {
                                        Image(systemName: symbol(for: room.kind)).font(.system(size: 26))
                                        Text(room.name).font(theme.font(13)).lineLimit(1)
                                    }
                                    .frame(width: 110, height: 84)
                                    .background(room.id == currentRoomID ? theme.selection.opacity(0.4) : theme.card,
                                                in: RoundedRectangle(cornerRadius: theme.cornerRadius * 0.6))
                                    .overlay(RoundedRectangle(cornerRadius: theme.cornerRadius * 0.6)
                                        .stroke(theme.ink.opacity(room.id == currentRoomID ? 1 : 0.35), lineWidth: 1.5))
                                    .foregroundStyle(theme.ink)
                                }
                                .buttonStyle(.plain)
                            }
                            Spacer()
                        }
                        .padding(12)

                        if let roomID = currentRoomID {
                            RoomSceneView(roomID: roomID, houseID: houseID)
                                .padding([.trailing, .bottom], 16)
                        }
                    }
                }
            } else {
                EmptyHint(title: "Huset findes ikke", text: "Det er måske blevet slettet.")
            }
        }
        .gameScreen()
        .sheet(isPresented: $showFacadePicker) {
            if let house {
                FacadePickerSheet(house: house)
                    .environment(model).environment(\.theme, theme)
            }
        }
    }

    private var currentRoomID: UUID? {
        selectedRoomID ?? house?.roomsTopDown.first(where: { $0.kind == .indoor })?.id ?? house?.rooms.first?.id
    }

    private func symbol(for kind: RoomKind) -> String {
        switch kind {
        case .indoor: return "bed.double"
        case .garden: return "leaf"
        case .roofTerrace: return "sun.max"
        case .balcony: return "building"
        case .street: return "road.lanes"
        }
    }
}

struct FacadePickerSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    let house: House
    @State private var painting = false

    var body: some View {
        VStack(spacing: 20) {
            Text("Hvordan ser huset ud udefra?").font(theme.font(26)).foregroundStyle(theme.ink).padding(.top, 20)
            if model.library.facades.isEmpty {
                EmptyHint(title: "Ingen hus-tegninger endnu", text: "Tegn et hus set udefra og læg det ind som \"Hus (set udefra)\".", symbol: "house")
            } else {
                ScrollView(.horizontal) {
                    HStack(spacing: 20) {
                        ForEach(model.library.facades) { f in
                            Button {
                                var h = house
                                h.facadeAssetID = f.id
                                h.facadePaint = .none
                                model.game.upsert(h)
                            } label: {
                                AssetThumbnail(assetID: f.id, selected: house.facadeAssetID == f.id, size: 200)
                            }.buttonStyle(.plain)
                        }
                    }.padding(24)
                }
            }
            HStack(spacing: 20) {
                if house.facadeAssetID != nil {
                    Button("Farv huset") { painting = true }.font(theme.font(20))
                }
                Button("Luk") { dismiss() }.font(theme.font(20))
            }
            .padding(.bottom, 20)
        }
        .frame(minWidth: 600, minHeight: 380)
        .background(theme.paper)
        .sheet(isPresented: $painting) {
            if let f = house.facadeAssetID {
                PaintView(assetID: f, paint: house.facadePaint) { p in
                    var h = house
                    h.facadePaint = p
                    model.game.upsert(h)
                }
                .environment(model).environment(\.theme, theme)
            }
        }
    }
}
