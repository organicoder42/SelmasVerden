import Foundation
import CoreGraphics

/// Gætter groft ud fra form, når der ikke er netværk. Rammer sjældent rigtigt på kategori, men giver
/// en fornuftig standard, som forælderen retter i oversigten. Konfidens er altid lav.
struct HeuristicClassifier: ClassificationService {
    let displayName = "Lokalt gæt (uden net)"

    func classify(pieces: [Data], sheetHint: Data?) async throws -> [PieceClassification] {
        pieces.enumerated().map { (i, data) in
            var category: AssetCategory = .unknown
            if let img = ImageIO.loadCGImage(from: data) {
                let aspect = Double(img.width) / Double(max(1, img.height))
                if aspect > 2.2 { category = .floor }
                else if aspect > 1.3 { category = .furniture }
                else if aspect < 0.45 { category = .body }
                else if aspect < 0.8 { category = .dress }
                else { category = .decoration }
            }
            return PieceClassification(index: i, category: category, name: "Tegning \(i + 1)",
                                       confidence: 0.15, subparts: [], anchors: nil, notes: "Gættet lokalt")
        }
    }
}
