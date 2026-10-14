import Foundation
import CoreGraphics

/// Et stykke af et ark, klar til godkendelse: billede + forslag fra sorteringen.
struct ImportedPiece: Identifiable, Sendable {
    let id = UUID()
    var image: CGImage
    var rectInSheet: CGRect
    var category: AssetCategory
    var name: String
    var confidence: Double
    var subparts: [SubpartSuggestion]
    var anchors: [String: CGPoint]?
    /// For dele skåret ud af en hel figur: hvor delen sad på kroppen, så den lander samme sted i spillet.
    var fit: AssetFit?
    var notes: String?
    /// Sat af forælderen i oversigten: skal denne del med?
    var accepted: Bool = true

    var pixelSize: CGSize { CGSize(width: image.width, height: image.height) }
}

/// Status der vises mens arket behandles.
enum ImportStage: Equatable, Sendable {
    case idle
    case straightening
    case cuttingOut
    case splitting
    case classifying(count: Int)
    case done
    case failed(String)

    var danishText: String {
        switch self {
        case .idle: return ""
        case .straightening: return "Retter papiret op…"
        case .cuttingOut: return "Klipper tegningen ud af papiret…"
        case .splitting: return "Finder de enkelte tegninger…"
        case .classifying(let n): return "Finder ud af hvad de \(n) tegninger er…"
        case .done: return "Færdig!"
        case .failed(let s): return "Noget gik galt: \(s)"
        }
    }
}

/// Hele vejen fra foto til godkendelses-klare dele. Kører tungt arbejde væk fra hovedtråden.
struct ImportPipeline: Sendable {
    var classifier: any ClassificationService
    var fallbackClassifier: any ClassificationService = HeuristicClassifier()
    var straighten: Bool = true
    var maxWorkingSide: Int = 2000
    var maxClassifySide: Int = 512

    func run(photo: CGImage, progress: @Sendable @MainActor (ImportStage) -> Void) async -> Result<[ImportedPiece], Error> {
        do {
            // 1) Arbejdskopi i håndterbar størrelse
            var working = ImageIO.downscaled(photo, maxSide: maxWorkingSide)

            // 2) Perspektiv
            if straighten {
                await progress(.straightening)
                working = PaperDetector.straightened(working)
            }

            // 3) Papir væk
            await progress(.cuttingOut)
            guard let raster = RasterImage(cgImage: working) else { throw ImportError.couldNotReadImage }
            let cut = await Task.detached(priority: .userInitiated) { PaperCutout.cutout(raster) }.value

            // 4) Del op
            await progress(.splitting)
            let components = await Task.detached(priority: .userInitiated) { ComponentSplitter.split(cut) }.value
            guard !components.isEmpty else { throw ImportError.nothingFound }

            var pieces: [ImportedPiece] = []
            var pngs: [Data] = []
            for c in components {
                guard let cg = c.image.cgImage() else { continue }
                pieces.append(ImportedPiece(image: cg, rectInSheet: c.rect, category: .unknown,
                                            name: "Tegning \(pieces.count + 1)", confidence: 0, subparts: []))
                let small = ImageIO.downscaled(cg, maxSide: maxClassifySide)
                pngs.append(ImageIO.pngData(small) ?? Data())
            }

            // 5) Sortér
            await progress(.classifying(count: pieces.count))
            let hint = ImageIO.pngData(ImageIO.downscaled(working, maxSide: 768))
            let results: [PieceClassification]
            do {
                results = try await classifier.classify(pieces: pngs, sheetHint: hint)
            } catch {
                // Uden net eller nøgle: gæt lokalt og lad forælderen rette. Fejlen vises som note.
                results = try await fallbackClassifier.classify(pieces: pngs, sheetHint: nil).map {
                    var r = $0
                    r.notes = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                    return r
                }
            }
            for r in results where r.index < pieces.count {
                pieces[r.index].category = r.category
                pieces[r.index].name = r.name
                pieces[r.index].confidence = r.confidence
                pieces[r.index].subparts = r.subparts
                pieces[r.index].anchors = r.anchors?.mapValues(\.cgPoint)
                pieces[r.index].notes = r.notes
            }

            await progress(.done)
            return .success(pieces)
        } catch {
            await progress(.failed((error as? LocalizedError)?.errorDescription ?? error.localizedDescription))
            return .failure(error)
        }
    }

    /// Skær en hel figur op i de dele sorteringen foreslog. Kroppen får ankre regnet ud fra delenes bokse.
    static func splitFullCharacter(_ piece: ImportedPiece) -> [ImportedPiece] {
        guard let raster = RasterImage(cgImage: piece.image), !piece.subparts.isEmpty else { return [piece] }
        let w = CGFloat(raster.width), h = CGFloat(raster.height)
        var out: [ImportedPiece] = []
        var anchors: [String: CGPoint] = [:]
        for sp in piece.subparts {
            let r = sp.box.cgRect
            let x = Int(r.minX * w), y = Int(r.minY * h), cw = Int(r.width * w), ch = Int(r.height * h)
            guard cw > 4, ch > 4 else { continue }
            if sp.category == .body {
                // Kroppen beholder hele figuren (tøjet males over senere) - ankre fra de andre dele
                continue
            }
            let crop = raster.cropped(x: x, y: y, width: cw, height: ch)
            guard let cg = crop.cgImage() else { continue }
            if let slot = sp.category.wearableSlot {
                anchors[slot.rawValue] = CGPoint(x: r.midX, y: r.midY)
            }
            var p = ImportedPiece(image: cg, rectInSheet: piece.rectInSheet, category: sp.category, name: sp.name,
                                  confidence: piece.confidence * 0.8, subparts: [])
            // Pasformen er boksens placering i kroppens billede - så trøjen sidder hvor Selma tegnede den.
            p.fit = AssetFit(center: CGPoint(x: r.midX, y: r.midY), heightRatio: r.height)
            p.notes = "Skåret ud af \(piece.name)"
            out.append(p)
        }
        var body = piece
        body.category = .body
        body.name = "Krop fra \(piece.name)"
        body.subparts = []
        body.anchors = piece.anchors ?? anchors
        out.insert(body, at: 0)
        return out
    }
}

enum ImportError: LocalizedError {
    case couldNotReadImage
    case nothingFound

    var errorDescription: String? {
        switch self {
        case .couldNotReadImage: return "Billedet kunne ikke læses."
        case .nothingFound: return "Jeg kunne ikke finde nogen tegning på billedet. Prøv med mere lys og hvidt papir."
        }
    }
}
