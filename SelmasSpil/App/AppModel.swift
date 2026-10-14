import Foundation
import Observation
import CoreGraphics

/// Spillets ene sandhed: biblioteket af tegninger, det gemte spil, stilen og AI-opsætningen.
@MainActor
@Observable
final class AppModel {
    let library = AssetLibrary()
    let renderer: AssetRenderer
    private let saveStore = SaveStore()

    var game: SaveGame = .empty {
        didSet { saveStore.scheduleSave(game) }
    }
    var theme = Theme(seed: StyleSeed.load())
    var aiConfig = AIConfig.load() {
        didSet { aiConfig.save() }
    }

    init() {
        renderer = AssetRenderer(library: library)
    }

    func start() {
        library.load()
        game = saveStore.load()
        if game.houses.isEmpty {
            game.upsert(House.starter(name: "Selmas hus"))
        }
    }

    func saveNow() {
        saveStore.saveNow(game)
    }

    // MARK: - AI

    var hasAPIAccess: Bool {
        aiConfig.usesProxy || !(KeychainStore.apiKey ?? "").isEmpty
    }

    func makeClassifier() -> any ClassificationService {
        if hasAPIAccess {
            return ClaudeClassifier(config: aiConfig, apiKey: KeychainStore.apiKey)
        }
        return HeuristicClassifier()
    }

    func makePipeline() -> ImportPipeline {
        ImportPipeline(classifier: makeClassifier())
    }

    // MARK: - Import: gem godkendte dele

    func commit(pieces: [ImportedPiece]) throws -> [DrawingAsset] {
        var saved: [DrawingAsset] = []
        for p in pieces where p.accepted && p.category != .unknown {
            let asset = try library.add(image: p.image, name: p.name, category: p.category,
                                        tags: p.notes.map { [$0] } ?? [], fit: p.fit, anchors: p.anchors)
            saved.append(asset)
        }
        renderer.invalidate()
        return saved
    }

    // MARK: - Figurer

    func newCharacter(named name: String, bodyAssetID: UUID) -> GameCharacter {
        let c = GameCharacter(name: name, bodyAssetID: bodyAssetID)
        game.upsert(c)
        return c
    }

    // MARK: - Huse

    func newHouse(named name: String) -> House {
        let h = House.starter(name: name)
        game.upsert(h)
        return h
    }

    func room(id: UUID) -> (house: House, room: Room)? {
        for h in game.houses {
            if let r = h.rooms.first(where: { $0.id == id }) { return (h, r) }
        }
        return nil
    }

    func update(room: Room, in houseID: UUID) {
        guard var h = game.house(id: houseID) else { return }
        h.update(room)
        game.upsert(h)
    }
}
