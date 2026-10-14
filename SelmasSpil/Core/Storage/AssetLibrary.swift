import Foundation
import CoreGraphics
import Observation

/// Biblioteket over alle tegninger: dem der følger med spillet (bundle) og dem brugeren har lagt ind.
/// Billeder caches i hukommelsen; metadata ligger i to manifester.
@MainActor
@Observable
final class AssetLibrary {
    private(set) var assets: [DrawingAsset] = []
    private(set) var loadError: String?

    private let imageCache = NSCache<NSString, CGImageBox>()
    private var userManifest = AssetManifest()

    init() {
        imageCache.countLimit = 400
    }

    // MARK: - Indlæsning

    func load() {
        var all: [DrawingAsset] = []
        if let url = FileLocations.bundledManifest, let m = JSONStore.loadIfExists(AssetManifest.self, from: url) {
            all.append(contentsOf: m.assets.map { var a = $0; a.source = .bundled; return a })
        }
        do {
            try FileLocations.ensureDirectories()
        } catch {
            loadError = "Kunne ikke oprette mapper: \(error.localizedDescription)"
        }
        if let m = JSONStore.loadIfExists(AssetManifest.self, from: FileLocations.userManifest) {
            userManifest = m
            all.append(contentsOf: m.assets.map { var a = $0; a.source = .imported; return a })
        }
        assets = all.sorted { $0.createdAt > $1.createdAt }
    }

    // MARK: - Opslag

    func asset(id: UUID) -> DrawingAsset? {
        assets.first { $0.id == id }
    }

    func assets(in category: AssetCategory) -> [DrawingAsset] {
        assets.filter { $0.category == category }
    }

    func assets(in categories: [AssetCategory]) -> [DrawingAsset] {
        let set = Set(categories)
        return assets.filter { set.contains($0.category) }
    }

    func assets(for slot: WearableSlot) -> [DrawingAsset] {
        assets(in: slot.category)
    }

    var bodies: [DrawingAsset] { assets(in: .body) }
    var patterns: [DrawingAsset] { assets(in: .pattern) }
    var facades: [DrawingAsset] { assets(in: .houseFacade) }

    /// Har vi overhovedet noget at bygge en figur af?
    var canBuildCharacters: Bool { !bodies.isEmpty }

    /// Håndtegnet knap/ikon til brugerfladen, slået op på navn ("Leg", "Flyt", "Kamera" ...).
    /// Forælderen navngiver ikonet som knappen hedder, og så bruges det automatisk. Nil = brug systemsymbolet.
    func uiIcon(named key: String) -> DrawingAsset? {
        let k = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !k.isEmpty else { return nil }
        return assets.first { $0.category == .uiIcon && $0.name.trimmingCharacters(in: .whitespacesAndNewlines).caseInsensitiveCompare(k) == .orderedSame }
    }

    /// Billedet af et håndtegnet ikon, hvis det findes.
    func uiIconImage(named key: String) -> CGImage? {
        uiIcon(named: key).flatMap { image(for: $0) }
    }

    func imageURL(for asset: DrawingAsset) -> URL? {
        switch asset.source {
        case .bundled: return FileLocations.bundledAssets?.appendingPathComponent(asset.imageFile)
        case .imported: return FileLocations.userAssets.appendingPathComponent(asset.imageFile)
        }
    }

    /// Originalbilledet uden maling. Cachet.
    func image(for asset: DrawingAsset) -> CGImage? {
        let key = asset.id.uuidString as NSString
        if let boxed = imageCache.object(forKey: key) { return boxed.image }
        guard let url = imageURL(for: asset), let img = ImageIO.loadCGImage(from: url) else { return nil }
        imageCache.setObject(CGImageBox(img), forKey: key)
        return img
    }

    func image(forAssetID id: UUID) -> CGImage? {
        guard let a = asset(id: id) else { return nil }
        return image(for: a)
    }

    // MARK: - Ændringer

    /// Læg en ny tegning ind. Billedet skrives som PNG og manifestet opdateres.
    @discardableResult
    func add(image: CGImage, name: String, category: AssetCategory, tags: [String] = [],
             fit: AssetFit? = nil, anchors: [String: CGPoint]? = nil) throws -> DrawingAsset {
        try FileLocations.ensureDirectories()
        let id = UUID()
        let file = "\(category.rawValue)-\(id.uuidString.prefix(8)).png"
        try ImageIO.savePNG(image, to: FileLocations.userAssets.appendingPathComponent(file))
        let asset = DrawingAsset(
            id: id, name: name, category: category, imageFile: file,
            pixelSize: CGSize(width: image.width, height: image.height),
            source: .imported, tags: tags, fit: fit, anchors: anchors,
            defaultHeight: Self.defaultHeight(for: category, aspect: CGFloat(image.width) / CGFloat(max(1, image.height)))
        )
        userManifest.assets.append(asset)
        try JSONStore.save(userManifest, to: FileLocations.userManifest)
        assets.insert(asset, at: 0)
        imageCache.setObject(CGImageBox(image), forKey: id.uuidString as NSString)
        return asset
    }

    func update(_ asset: DrawingAsset) throws {
        guard asset.source == .imported else { return } // bundlede assets er skrivebeskyttede
        if let i = userManifest.assets.firstIndex(where: { $0.id == asset.id }) {
            userManifest.assets[i] = asset
            try JSONStore.save(userManifest, to: FileLocations.userManifest)
        }
        if let i = assets.firstIndex(where: { $0.id == asset.id }) {
            assets[i] = asset
        }
    }

    func delete(_ asset: DrawingAsset) throws {
        guard asset.source == .imported else { return }
        userManifest.assets.removeAll { $0.id == asset.id }
        try JSONStore.save(userManifest, to: FileLocations.userManifest)
        if let url = imageURL(for: asset) {
            try? FileManager.default.removeItem(at: url)
        }
        assets.removeAll { $0.id == asset.id }
        imageCache.removeObject(forKey: asset.id.uuidString as NSString)
    }

    /// Fornuftig startstørrelse i et rum, ud fra hvad det er.
    static func defaultHeight(for category: AssetCategory, aspect: CGFloat) -> CGFloat? {
        switch category {
        case .furniture: return 0.35
        case .decoration, .toy, .food: return 0.15
        case .plant, .flower: return 0.25
        case .pet: return 0.2
        case .vehicle: return 0.3
        case .tree: return 0.7
        case .door: return 0.6
        case .window: return 0.3
        case .stairs: return 0.8
        case .fence: return 0.25
        case .outdoorItem: return 0.3
        default: return nil
        }
    }
}

/// NSCache kræver en klasse.
final class CGImageBox {
    let image: CGImage
    init(_ image: CGImage) { self.image = image }
}
