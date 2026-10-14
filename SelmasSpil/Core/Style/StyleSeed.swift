import Foundation
import CoreGraphics

/// Stilen i spillet laves IKKE af os - den udledes af Selmas tegninger.
/// Denne fil beskriver hvad der kan udledes: farvepalet, stregtykkelse, "ruhed" og tegnede UI-ikoner.
/// `Resources/Style/StyleSeed.json` genereres af Tools/ingest ud fra den første tegning
/// og opdateres løbende. Indtil da bruges en bevidst neutral grå stil, der ikke stjæler opmærksomhed.
struct StyleSeed: Codable, Sendable {
    /// Farver trukket ud af tegningerne, sorteret efter hvor meget de fylder.
    var palette: [RGBA]
    /// Papirets farve, som den så ud på fotoet (bruges som "baggrundsfølelse").
    var paper: RGBA
    /// Den mørke stregfarve Selma tegner konturer med (ofte ikke helt sort).
    var ink: RGBA
    /// Gennemsnitlig stregtykkelse i promille af tegningens højde. Styrer tykkelsen på rammer og knapper.
    var strokeWeight: Double
    /// Hjørnerunding på knapper og kort, 0 = kantet, 1 = helt runde. Udledes af hvor runde hendes former er.
    var roundness: Double
    /// Navn på font. Starter som systemets runde font; kan senere blive en font lavet af hendes bogstaver.
    var fontName: String?
    /// Hvilken tegning seedet blev lavet af.
    var derivedFrom: [String]
    var generatedAt: Date?
    /// Farver til udendørs-scenerne (himmel, asfalt, græs, buske), indtil Selma har tegnet dem som assets.
    var scene: SceneColors

    init(palette: [RGBA], paper: RGBA, ink: RGBA, strokeWeight: Double, roundness: Double, fontName: String?,
         derivedFrom: [String], generatedAt: Date?, scene: SceneColors = .standard) {
        self.palette = palette
        self.paper = paper
        self.ink = ink
        self.strokeWeight = strokeWeight
        self.roundness = roundness
        self.fontName = fontName
        self.derivedFrom = derivedFrom
        self.generatedAt = generatedAt
        self.scene = scene
    }

    private enum CodingKeys: String, CodingKey {
        case palette, paper, ink, strokeWeight, roundness, fontName, derivedFrom, generatedAt, scene
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        palette = try c.decode([RGBA].self, forKey: .palette)
        paper = try c.decode(RGBA.self, forKey: .paper)
        ink = try c.decode(RGBA.self, forKey: .ink)
        strokeWeight = try c.decode(Double.self, forKey: .strokeWeight)
        roundness = try c.decode(Double.self, forKey: .roundness)
        fontName = try c.decodeIfPresent(String.self, forKey: .fontName)
        derivedFrom = try c.decode([String].self, forKey: .derivedFrom)
        generatedAt = try c.decodeIfPresent(Date.self, forKey: .generatedAt)
        scene = try c.decodeIfPresent(SceneColors.self, forKey: .scene) ?? .standard
    }

    static let neutral = StyleSeed(
        palette: [
            RGBA(hex: "#E8E6E1")!, RGBA(hex: "#BFBBB3")!, RGBA(hex: "#8E8A82")!, RGBA(hex: "#F6F4EF")!,
        ],
        paper: RGBA(hex: "#F6F4EF")!,
        ink: RGBA(hex: "#3A3733")!,
        strokeWeight: 6,
        roundness: 0.5,
        fontName: nil,
        derivedFrom: [],
        generatedAt: nil
    )

    var isNeutral: Bool { derivedFrom.isEmpty }

    static func load() -> StyleSeed {
        if let url = FileLocations.bundledStyleSeed, let seed = JSONStore.loadIfExists(StyleSeed.self, from: url) {
            return seed
        }
        return .neutral
    }
}

/// Baggrundsfarver til scenerne udenfor. Bruges kun indtil der findes tegnede assets i kategorierne
/// `sky` og `ground` - så vinder tegningerne. Værdierne ligger i StyleSeed.json, ikke i koden.
struct SceneColors: Codable, Sendable {
    /// Himlen bag alle udendørs-scener.
    var sky: RGBA
    /// Vejen på gaden.
    var asphalt: RGBA
    /// Jorden i haven og på terrasser.
    var grass: RGBA
    /// Buskene langs gaden.
    var bush: RGBA

    static let standard = SceneColors(
        sky: RGBA(hex: "#BFE3F7")!, asphalt: RGBA(hex: "#8A8D93")!,
        grass: RGBA(hex: "#A8D672")!, bush: RGBA(hex: "#6FBF5A")!
    )
}
