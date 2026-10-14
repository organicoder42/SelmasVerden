import Foundation
import CoreGraphics

/// Et hus med flere rum, have og tagterrasse. Hvert rum er en scene man kan indrette.
struct House: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    var name: String
    /// Tegningen af huset set udefra (vises på verdenskortet).
    var facadeAssetID: UUID?
    var facadePaint: PaintState
    var rooms: [Room]
    var createdAt: Date

    init(id: UUID = UUID(), name: String, facadeAssetID: UUID? = nil, facadePaint: PaintState = .none,
         rooms: [Room] = [], createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.facadeAssetID = facadeAssetID
        self.facadePaint = facadePaint
        self.rooms = rooms
        self.createdAt = createdAt
    }

    /// Et nyt hus starter med have, to etager og tagterrasse.
    static func starter(name: String) -> House {
        House(name: name, rooms: [
            Room(name: "Tagterrasse", kind: .roofTerrace, level: 3),
            Room(name: "Ovenpå", kind: .indoor, level: 2),
            Room(name: "Stuen", kind: .indoor, level: 1),
            Room(name: "Haven", kind: .garden, level: 0),
        ])
    }

    /// Rum sorteret fra top (tagterrasse) til bund (have), som man ser dem i huset.
    var roomsTopDown: [Room] {
        rooms.sorted { $0.level > $1.level }
    }

    mutating func update(_ room: Room) {
        if let i = rooms.firstIndex(where: { $0.id == room.id }) {
            rooms[i] = room
        }
    }
}

enum RoomKind: String, Codable, CaseIterable, Sendable {
    case indoor
    case garden
    case roofTerrace
    case balcony
    /// Gaden foran husene - verdens fælles udendørs-scene.
    case street

    var isOutdoor: Bool { self != .indoor }

    var danishName: String {
        switch self {
        case .indoor: return "Rum"
        case .garden: return "Have"
        case .roofTerrace: return "Tagterrasse"
        case .balcony: return "Altan"
        case .street: return "Gaden"
        }
    }

    /// Hvilke kategorier det giver mening at stille her.
    var allowedCategories: [AssetCategory] {
        switch self {
        case .indoor:
            return [.furniture, .decoration, .plant, .toy, .food, .pet, .door, .window, .stairs]
        case .garden, .street:
            return [.tree, .flower, .outdoorItem, .furniture, .plant, .toy, .pet, .vehicle, .fence, .food, .decoration]
        case .roofTerrace, .balcony:
            return [.furniture, .plant, .flower, .outdoorItem, .toy, .food, .decoration, .pet, .fence]
        }
    }
}

struct Room: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    var name: String
    var kind: RoomKind
    /// Etage. 0 = have/gade, 1 = stuen, 2 = ovenpå, højeste = tag.
    var level: Int
    var wallAssetID: UUID?
    var wallPaint: PaintState
    var floorAssetID: UUID?
    var floorPaint: PaintState
    var skyAssetID: UUID?
    var placements: [Placement]

    init(id: UUID = UUID(), name: String, kind: RoomKind, level: Int,
         wallAssetID: UUID? = nil, wallPaint: PaintState = .none,
         floorAssetID: UUID? = nil, floorPaint: PaintState = .none,
         skyAssetID: UUID? = nil, placements: [Placement] = []) {
        self.id = id
        self.name = name
        self.kind = kind
        self.level = level
        self.wallAssetID = wallAssetID
        self.wallPaint = wallPaint
        self.floorAssetID = floorAssetID
        self.floorPaint = floorPaint
        self.skyAssetID = skyAssetID
        self.placements = placements
    }

    var nextZIndex: Int { (placements.map(\.zIndex).max() ?? 0) + 1 }

    mutating func add(_ placement: Placement) {
        var p = placement
        p.zIndex = nextZIndex
        placements.append(p)
    }

    mutating func update(_ placement: Placement) {
        if let i = placements.firstIndex(where: { $0.id == placement.id }) {
            placements[i] = placement
        }
    }

    mutating func remove(id: UUID) {
        placements.removeAll { $0.id == id }
    }

    mutating func bringToFront(id: UUID) {
        guard let i = placements.firstIndex(where: { $0.id == id }) else { return }
        placements[i].zIndex = nextZIndex
    }
}

/// Noget der står i et rum: et møbel, en plante eller en figur.
struct Placement: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    var content: PlacedContent
    /// Midtpunkt, normaliseret 0...1 i rummets bredde/højde.
    var position: CGPoint
    /// Højde som andel af rummets højde.
    var height: CGFloat
    var rotation: Double
    var flipped: Bool
    var zIndex: Int
    /// Farver og mønstre - kun for ting (figurer har deres egen maling).
    var paint: PaintState

    init(id: UUID = UUID(), content: PlacedContent, position: CGPoint, height: CGFloat,
         rotation: Double = 0, flipped: Bool = false, zIndex: Int = 0, paint: PaintState = .none) {
        self.id = id
        self.content = content
        self.position = position
        self.height = height
        self.rotation = rotation
        self.flipped = flipped
        self.zIndex = zIndex
        self.paint = paint
    }
}

enum PlacedContent: Codable, Hashable, Sendable {
    case asset(UUID)
    case character(UUID)

    var assetID: UUID? {
        if case .asset(let id) = self { return id }
        return nil
    }

    var characterID: UUID? {
        if case .character(let id) = self { return id }
        return nil
    }
}
