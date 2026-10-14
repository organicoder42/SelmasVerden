import Foundation
import CoreGraphics

/// En figur: en krop plus det der sidder på den. Hver plads (hår, trøje, sko ...) er sin egen tegning.
struct GameCharacter: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    var name: String
    var bodyAssetID: UUID
    var bodyPaint: PaintState
    var worn: [WearableSlot: WornItem]
    var createdAt: Date

    init(id: UUID = UUID(), name: String, bodyAssetID: UUID, bodyPaint: PaintState = .none,
         worn: [WearableSlot: WornItem] = [:], createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.bodyAssetID = bodyAssetID
        self.bodyPaint = bodyPaint
        self.worn = worn
        self.createdAt = createdAt
    }

    /// Tag noget på. Fjerner automatisk det der ikke kan bæres samtidig (kjole vs. trøje/bukser).
    mutating func wear(_ assetID: UUID, in slot: WearableSlot) {
        for conflict in slot.conflicts { worn[conflict] = nil }
        worn[slot] = WornItem(assetID: assetID)
    }

    mutating func remove(slot: WearableSlot) {
        worn[slot] = nil
    }

    /// Alle lag i tegne-rækkefølge (krop først).
    var layers: [CharacterLayer] {
        var result = [CharacterLayer(slot: nil, assetID: bodyAssetID, paint: bodyPaint, fitOverride: nil, zIndex: 0)]
        for (slot, item) in worn {
            result.append(CharacterLayer(slot: slot, assetID: item.assetID, paint: item.paint,
                                         fitOverride: item.fitOverride, zIndex: slot.zIndex))
        }
        return result.sorted { $0.zIndex < $1.zIndex }
    }
}

struct WornItem: Codable, Hashable, Sendable {
    var assetID: UUID
    var paint: PaintState
    /// Hvis barnet har rykket eller skaleret delen på netop denne figur.
    var fitOverride: AssetFit?

    init(assetID: UUID, paint: PaintState = .none, fitOverride: AssetFit? = nil) {
        self.assetID = assetID
        self.paint = paint
        self.fitOverride = fitOverride
    }
}

struct CharacterLayer: Hashable, Identifiable, Sendable {
    var slot: WearableSlot?
    var assetID: UUID
    var paint: PaintState
    var fitOverride: AssetFit?
    var zIndex: Int

    var id: String { slot?.rawValue ?? "body" }
}
