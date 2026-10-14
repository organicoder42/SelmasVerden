import Foundation
import CoreGraphics

/// En enkelt tegning der er lagt ind i spillet - et stykke tøj, et møbel, en frisure, et mønster osv.
/// Selve billedet ligger som PNG med gennemsigtig baggrund; denne struct er kun metadata.
struct DrawingAsset: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    var name: String
    var category: AssetCategory
    /// Filnavn relativt til asset-mappen (bundle: Resources/BuiltIn, bruger: Documents/Assets).
    var imageFile: String
    var pixelSize: CGSize
    var source: AssetSource
    var createdAt: Date
    var tags: [String]
    /// For tøj og figur-dele: hvordan den sidder på kroppen. Nil = brug standard-ankeret fra riggen.
    var fit: AssetFit?
    /// For kroppe: hvor de enkelte pladser sidder (normaliseret 0...1 i kroppens billede).
    var anchors: [String: CGPoint]?
    /// For møbler og ting: standardhøjde i rummet (andel af rummets højde, 0...1).
    var defaultHeight: CGFloat?
    var paintable: Bool
    /// Hvem har tegnet den (f.eks. "Selma"). Kan bruges til credits og filtrering.
    var artist: String?

    init(
        id: UUID = UUID(),
        name: String,
        category: AssetCategory,
        imageFile: String,
        pixelSize: CGSize,
        source: AssetSource = .imported,
        createdAt: Date = Date(),
        tags: [String] = [],
        fit: AssetFit? = nil,
        anchors: [String: CGPoint]? = nil,
        defaultHeight: CGFloat? = nil,
        paintable: Bool? = nil,
        artist: String? = "Selma"
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.imageFile = imageFile
        self.pixelSize = pixelSize
        self.source = source
        self.createdAt = createdAt
        self.tags = tags
        self.fit = fit
        self.anchors = anchors
        self.defaultHeight = defaultHeight
        self.paintable = paintable ?? category.isPaintableByDefault
        self.artist = artist
    }

    var aspectRatio: CGFloat {
        guard pixelSize.height > 0 else { return 1 }
        return pixelSize.width / pixelSize.height
    }

    var wearableSlot: WearableSlot? { category.wearableSlot }
}

enum AssetSource: String, Codable, Sendable {
    /// Ligger i app-bundlet (Selmas tegninger der følger med spillet).
    case bundled
    /// Lagt ind af brugeren på enheden.
    case imported
}

/// Hvordan en del sidder på kroppen. Alt er relativt til kroppens billede,
/// så den samme trøje passer uanset hvor stor kroppen vises.
struct AssetFit: Codable, Hashable, Sendable {
    /// Midtpunkt af delen, normaliseret 0...1 i kroppens bredde/højde.
    var center: CGPoint
    /// Delens højde som andel af kroppens højde.
    var heightRatio: CGFloat
    /// Rotation i radianer.
    var rotation: Double

    init(center: CGPoint, heightRatio: CGFloat, rotation: Double = 0) {
        self.center = center
        self.heightRatio = heightRatio
        self.rotation = rotation
    }
}

/// Manifestet der ligger ved siden af PNG-filerne. Samme format for bundle og brugerbibliotek.
struct AssetManifest: Codable, Sendable {
    var version: Int
    var assets: [DrawingAsset]

    static let currentVersion = 1

    init(version: Int = AssetManifest.currentVersion, assets: [DrawingAsset] = []) {
        self.version = version
        self.assets = assets
    }
}
