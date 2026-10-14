import SwiftUI

/// Selve legescenen: et rum, en have, en tagterrasse eller gaden. Ting og figurer kan trækkes rundt,
/// gøres større/mindre, spejlvendes, farves og fjernes. Nye ting hentes fra skuffen i bunden.
struct RoomSceneView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var theme
    let roomID: UUID
    /// nil = gaden (ligger direkte på SaveGame)
    let houseID: UUID?

    @State private var selectedID: UUID?
    @State private var dragOffset: CGSize = .zero
    @State private var draggingID: UUID?
    @State private var pinchStartHeight: CGFloat?
    @State private var painting: Placement?
    @State private var drawerOpen = true
    @State private var wallPickerOpen = false
    /// Den ting der lige er sat ind - den "hopper" på plads.
    @State private var hopID: UUID?
    /// Tæller pr. ting; hver gang den stiger, vrikker tingen.
    @State private var wiggles: [UUID: Int] = [:]

    private var room: Room? {
        if let houseID { return model.game.house(id: houseID)?.rooms.first { $0.id == roomID } }
        return model.game.street
    }

    private func save(_ room: Room) {
        if let houseID { model.update(room: room, in: houseID) } else { model.game.street = room }
    }

    var body: some View {
        if let room {
            VStack(spacing: 10) {
                GeometryReader { geo in
                    ZStack {
                        background(room, size: geo.size)
                        ForEach(room.placements.sorted { $0.zIndex < $1.zIndex }) { placement in
                            placementView(placement, room: room, size: geo.size)
                        }
                        if room.placements.isEmpty {
                            VStack {
                                Spacer()
                                Text(room.kind.isOutdoor ? "Tryk på en ting nedenfor for at stille den udenfor" : "Tryk på en ting nedenfor for at stille den ind i rummet")
                                    .font(theme.font(16, weight: .regular)).foregroundStyle(theme.inkSoft)
                                    .padding(.bottom, 24)
                            }
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius))
                    .overlay(RoundedRectangle(cornerRadius: theme.cornerRadius).stroke(theme.ink, lineWidth: theme.strokeWidth))
                    .contentShape(Rectangle())
                    .onTapGesture { selectedID = nil }
                }

                // Værktøjslinje for den valgte ting
                if let sel = selectedID, let p = room.placements.first(where: { $0.id == sel }) {
                    HStack(spacing: 14) {
                        RoundIconButton(symbol: "paintbrush", label: "Farv", size: 48) { painting = p }
                            .disabled(p.content.assetID == nil)
                        RoundIconButton(symbol: "arrow.left.and.right", label: "Spejl", size: 48) {
                            var r = room; var q = p; q.flipped.toggle(); r.update(q); save(r)
                        }
                        RoundIconButton(symbol: "plus.magnifyingglass", label: "Større", size: 48) {
                            var r = room; var q = p; q.height = min(1.2, q.height * 1.15); r.update(q); save(r)
                        }
                        RoundIconButton(symbol: "minus.magnifyingglass", label: "Mindre", size: 48) {
                            var r = room; var q = p; q.height = max(0.03, q.height / 1.15); r.update(q); save(r)
                        }
                        RoundIconButton(symbol: "square.3.layers.3d.top.filled", label: "Forrest", size: 48) {
                            var r = room; r.bringToFront(id: p.id); save(r)
                        }
                        RoundIconButton(symbol: "plus.square.on.square", label: "Kopi", size: 48) {
                            var r = room; var q = p; q.id = UUID(); q.position.x = min(0.95, q.position.x + 0.05)
                            q.position.y = min(0.95, q.position.y + 0.05); r.add(q); save(r); selectedID = q.id
                        }
                        .disabled(p.content.characterID != nil)
                        RoundIconButton(symbol: "trash", label: "Fjern", size: 48) {
                            var r = room; r.remove(id: p.id); save(r); selectedID = nil
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 8)
                } else {
                    HStack(spacing: 14) {
                        RoundIconButton(symbol: drawerOpen ? "chevron.down" : "chevron.up", label: "Ting", size: 48, active: drawerOpen) { drawerOpen.toggle() }
                        if room.kind == .indoor || room.kind.isOutdoor {
                            RoundIconButton(symbol: "paintpalette", label: room.kind.isOutdoor ? "Baggrund" : "Vægge og gulv", size: 48) { wallPickerOpen = true }
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 8)
                }

                if drawerOpen {
                    ItemDrawerView(room: room) { asset in
                        let h = asset.defaultHeight ?? 0.3
                        place(Placement(content: .asset(asset.id), position: CGPoint(x: 0.5, y: room.kind.isOutdoor ? 0.7 : 0.65), height: h), in: room)
                    } onPickCharacter: { character in
                        place(Placement(content: .character(character.id), position: CGPoint(x: 0.4, y: 0.62), height: 0.6), in: room)
                    }
                    .frame(height: 150)
                }
            }
            .sheet(item: $painting) { p in
                if let assetID = p.content.assetID {
                    PaintView(assetID: assetID, paint: p.paint) { newPaint in
                        if var r = self.room {
                            var q = p; q.paint = newPaint; r.update(q); save(r)
                        }
                    }
                    .environment(model).environment(\.theme, theme)
                }
            }
            .sheet(isPresented: $wallPickerOpen) {
                SurfacePickerSheet(room: room, onSave: save)
                    .environment(model).environment(\.theme, theme)
            }
        }
    }

    /// Sæt en ny ting ind, vælg den, og lad den hoppe på plads.
    private func place(_ placement: Placement, in room: Room) {
        var r = room
        r.add(placement)
        hopID = placement.id
        save(r)
        selectedID = placement.id
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(40))
            withAnimation(.spring(duration: 0.55, bounce: 0.45)) { hopID = nil }
        }
    }

    // MARK: - Baggrund (væg/gulv eller himmel/jord)

    /// Indenfor: væg + gulv. Udenfor: himmel + jord. Gaden får asfalt og buske langs vejen, indtil Selma har
    /// tegnet himmel og jord (så vinder hendes tegninger). Farverne kommer fra `StyleSeed.scene`.
    @ViewBuilder
    private func background(_ room: Room, size: CGSize) -> some View {
        let outdoor = room.kind.isOutdoor
        let floorHeight = size.height * (outdoor ? 0.32 : 0.3)
        VStack(spacing: 0) {
            ZStack(alignment: .bottom) {
                outdoor ? theme.sky : theme.paper
                if let wall = outdoor ? room.skyAssetID : room.wallAssetID,
                   let img = model.renderer.image(for: wall, paint: room.wallPaint) {
                    Image(decorative: img, scale: 1).resizable().scaledToFill()
                }
                if room.kind == .street, room.floorAssetID == nil {
                    BushRow().frame(height: size.height * 0.14)
                }
            }
            .frame(height: size.height - floorHeight)
            .clipped()
            ZStack {
                switch room.kind {
                case .street: AsphaltRoad()
                case .indoor: theme.accent.opacity(0.35)
                default: theme.grass
                }
                if let floor = room.floorAssetID, let img = model.renderer.image(for: floor, paint: room.floorPaint) {
                    Image(decorative: img, scale: 1).resizable().scaledToFill()
                }
            }
            .frame(height: floorHeight)
            .clipped()
        }
    }

    // MARK: - Ting og figurer

    @ViewBuilder
    private func placementView(_ p: Placement, room: Room, size: CGSize) -> some View {
        let isSelected = selectedID == p.id
        let h = p.height * size.height
        let offset = draggingID == p.id ? dragOffset : .zero
        let pos = CGPoint(x: p.position.x * size.width + offset.width, y: p.position.y * size.height + offset.height)
        Group {
            switch p.content {
            case .asset(let assetID):
                if let asset = model.library.asset(id: assetID), let img = model.renderer.image(for: assetID, paint: p.paint) {
                    Image(decorative: img, scale: 1).resizable()
                        .frame(width: h * asset.aspectRatio, height: h)
                } else {
                    Color.clear.frame(width: h, height: h)
                }
            case .character(let charID):
                if let c = model.game.character(id: charID) {
                    let aspect = model.library.asset(id: c.bodyAssetID)?.aspectRatio ?? 0.5
                    CharacterView(character: c).frame(width: h * aspect, height: h)
                } else {
                    Color.clear.frame(width: h, height: h)
                }
            }
        }
        .scaleEffect(x: p.flipped ? -1 : 1, y: 1)
        .rotationEffect(.radians(p.rotation))
        // Vrik når man trykker: en lille rokken frem og tilbage omkring fødderne.
        .phaseAnimator([0.0, 7, -6, 4, -2, 0], trigger: wiggles[p.id] ?? 0) { view, angle in
            view.rotationEffect(.degrees(angle), anchor: .bottom)
        } animation: { _ in .spring(duration: 0.1, bounce: 0.3) }
        // Hop på plads når tingen lige er sat ind.
        .scaleEffect(hopID == p.id ? 0.6 : 1, anchor: .bottom)
        .offset(y: hopID == p.id ? -h * 0.4 : 0)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(theme.selection, style: StrokeStyle(lineWidth: isSelected ? 3 : 0, dash: [8, 6]))
                .padding(-6)
        )
        .position(pos)
        .zIndex(Double(p.zIndex))
        .gesture(
            DragGesture(minimumDistance: 1)
                .onChanged { v in
                    selectedID = p.id
                    draggingID = p.id
                    dragOffset = v.translation
                }
                .onEnded { v in
                    var r = room
                    var q = p
                    q.position.x = min(1.05, max(-0.05, p.position.x + v.translation.width / size.width))
                    q.position.y = min(1.05, max(-0.05, p.position.y + v.translation.height / size.height))
                    r.update(q)
                    r.bringToFront(id: q.id)
                    save(r)
                    draggingID = nil
                    dragOffset = .zero
                }
                .simultaneously(with: MagnifyGesture()
                    .onChanged { v in
                        selectedID = p.id
                        let start = pinchStartHeight ?? p.height
                        if pinchStartHeight == nil { pinchStartHeight = start }
                        var r = room; var q = p
                        q.height = min(1.2, max(0.03, start * v.magnification))
                        r.update(q); save(r)
                    }
                    .onEnded { _ in pinchStartHeight = nil })
        )
        .onTapGesture {
            selectedID = isSelected ? nil : p.id
            wiggles[p.id, default: 0] += 1
        }
    }
}

/// Vælg tapet/væg og gulv (indenfor) eller himmel og jord (udenfor), og farv dem.
struct SurfacePickerSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    @State var room: Room
    let onSave: (Room) -> Void
    @State private var paintingWall = false
    @State private var paintingFloor = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text(room.kind.isOutdoor ? "Himmel og jord" : "Vægge og gulv").font(theme.font(26)).foregroundStyle(theme.ink)
                Spacer()
                RoundIconButton(symbol: "checkmark", size: 48, active: true) { onSave(room); dismiss() }
            }
            surfaceRow(title: room.kind.isOutdoor ? "Himmel" : "Væg",
                       assets: model.library.assets(in: room.kind.isOutdoor ? [.sky] : [.wall, .pattern]),
                       selected: room.kind.isOutdoor ? room.skyAssetID : room.wallAssetID,
                       canPaint: (room.kind.isOutdoor ? room.skyAssetID : room.wallAssetID) != nil,
                       onPick: { id in
                           if room.kind.isOutdoor { room.skyAssetID = id } else { room.wallAssetID = id }
                           room.wallPaint = .none
                       },
                       onPaint: { paintingWall = true })
            surfaceRow(title: room.kind.isOutdoor ? "Jord / græs" : "Gulv",
                       assets: model.library.assets(in: room.kind.isOutdoor ? [.ground, .pattern] : [.floor, .pattern]),
                       selected: room.floorAssetID,
                       canPaint: room.floorAssetID != nil,
                       onPick: { id in room.floorAssetID = id; room.floorPaint = .none },
                       onPaint: { paintingFloor = true })
            Spacer()
        }
        .padding(24)
        .frame(minWidth: 640, minHeight: 420)
        .background(theme.paper)
        .sheet(isPresented: $paintingWall) {
            if let id = room.kind.isOutdoor ? room.skyAssetID : room.wallAssetID {
                PaintView(assetID: id, paint: room.wallPaint) { room.wallPaint = $0 }
                    .environment(model).environment(\.theme, theme)
            }
        }
        .sheet(isPresented: $paintingFloor) {
            if let id = room.floorAssetID {
                PaintView(assetID: id, paint: room.floorPaint) { room.floorPaint = $0 }
                    .environment(model).environment(\.theme, theme)
            }
        }
    }

    @ViewBuilder
    private func surfaceRow(title: String, assets: [DrawingAsset], selected: UUID?, canPaint: Bool,
                            onPick: @escaping (UUID?) -> Void, onPaint: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title).font(theme.font(18)).foregroundStyle(theme.ink)
                Spacer()
                if canPaint { Button("Farv") { onPaint() }.font(theme.font(16)) }
            }
            if assets.isEmpty {
                Text("Tegn en og læg den ind under \"Nye tegninger\".").font(theme.font(14, weight: .regular)).foregroundStyle(theme.inkSoft)
            } else {
                ScrollView(.horizontal) {
                    HStack(spacing: 12) {
                        Button { onPick(nil) } label: {
                            ZStack {
                                RoundedRectangle(cornerRadius: theme.cornerRadius * 0.6).fill(theme.card)
                                Image(systemName: "xmark").foregroundStyle(theme.inkSoft)
                            }
                            .frame(width: 90, height: 90)
                            .overlay(RoundedRectangle(cornerRadius: theme.cornerRadius * 0.6).stroke(theme.ink.opacity(selected == nil ? 1 : 0.3), lineWidth: 1.5))
                        }.buttonStyle(.plain)
                        ForEach(assets) { a in
                            Button { onPick(a.id) } label: {
                                AssetThumbnail(assetID: a.id, selected: selected == a.id, size: 90)
                            }.buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Gadens kulisser (indtil Selma har tegnet dem)

/// En række buske langs vejkanten: runde klatter med kontur i Selmas stregfarve og -tykkelse.
struct BushRow: View {
    @Environment(\.theme) private var theme

    var body: some View {
        Canvas { ctx, size in
            let count = max(3, Int(size.width / 120))
            for i in 0..<count {
                let cx = size.width * (CGFloat(i) + 0.5) / CGFloat(count)
                // lidt forskellige størrelser, men altid de samme for samme plads
                let r = size.height * (0.32 + 0.08 * CGFloat((i * 5) % 3))
                let blobs = [
                    CGRect(x: cx - r * 1.3, y: size.height - r * 1.5, width: r * 1.6, height: r * 1.6),
                    CGRect(x: cx + r * 0.0, y: size.height - r * 1.4, width: r * 1.5, height: r * 1.5),
                    CGRect(x: cx - r * 0.7, y: size.height - r * 2.0, width: r * 1.7, height: r * 1.9),
                    // bred fod, der rager ud under kanten, så bunden bliver flad mod vejen
                    CGRect(x: cx - r * 1.1, y: size.height - r * 0.9, width: r * 2.5, height: r * 1.6),
                ]
                // Foren klatterne til én silhuet, så konturen kun går rundt om hele busken
                var union = CGPath(ellipseIn: blobs[0], transform: nil)
                for b in blobs.dropFirst() { union = union.union(CGPath(ellipseIn: b, transform: nil)) }
                let path = Path(union)
                ctx.fill(path, with: .color(theme.bush))
                ctx.stroke(path, with: .color(theme.ink), style: StrokeStyle(lineWidth: theme.strokeWidth, lineJoin: .round))
            }
        }
    }
}

/// Vejen: asfalt med en stiplet midterstribe i papirets farve.
struct AsphaltRoad: View {
    @Environment(\.theme) private var theme

    var body: some View {
        Canvas { ctx, size in
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(theme.asphalt))
            var line = Path()
            line.move(to: CGPoint(x: 0, y: size.height * 0.55))
            line.addLine(to: CGPoint(x: size.width, y: size.height * 0.55))
            let dash = max(24, size.width * 0.05)
            ctx.stroke(line, with: .color(theme.paper.opacity(0.85)),
                       style: StrokeStyle(lineWidth: theme.strokeWidth * 1.5, lineCap: .round, dash: [dash, dash * 0.7]))
        }
    }
}
