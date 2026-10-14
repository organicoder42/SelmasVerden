import Foundation
import CoreGraphics

/// Hvad sorteringen skal svare for hver udskåret del.
struct PieceClassification: Codable, Sendable, Equatable {
    var index: Int
    var category: AssetCategory
    /// Kort dansk navn, f.eks. "Rød kjole med prikker".
    var name: String
    /// 0...1
    var confidence: Double
    /// Hvis delen er en hel figur eller flere ting i ét: forslag til opdeling (normaliserede bokse 0...1).
    var subparts: [SubpartSuggestion]
    /// For kroppe: hvor pladserne sidder. Nøgler er WearableSlot-rå-værdier.
    var anchors: [String: NormalizedPoint]?
    var notes: String?
}

struct SubpartSuggestion: Codable, Sendable, Equatable {
    var category: AssetCategory
    var name: String
    /// x, y, bredde, højde - alle 0...1 relativt til delens billede.
    var box: NormalizedBox
}

struct NormalizedBox: Codable, Sendable, Equatable {
    var x: Double; var y: Double; var width: Double; var height: Double
    var cgRect: CGRect { CGRect(x: x, y: y, width: width, height: height) }
}

struct NormalizedPoint: Codable, Sendable, Equatable {
    var x: Double; var y: Double
    var cgPoint: CGPoint { CGPoint(x: x, y: y) }
}

/// Sorteringen er udskiftelig: Claude via netværk, en lokal heuristik når der ikke er net,
/// eller en "manuel" der bare beder forælderen vælge.
protocol ClassificationService: Sendable {
    var displayName: String { get }
    /// `pieces` er PNG-data for hver del, i samme rækkefølge som indekserne i svaret.
    /// `sheetHint` er en lille udgave af hele arket til kontekst (kan være nil).
    func classify(pieces: [Data], sheetHint: Data?) async throws -> [PieceClassification]
}

enum ClassificationError: LocalizedError {
    case missingAPIKey
    case badResponse(String)
    case refused(String)
    case network(Error)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey: return "Der mangler en API-nøgle. Sæt den under Forældre → Indstillinger."
        case .badResponse(let s): return "Uventet svar fra sorteringen: \(s)"
        case .refused(let s): return "Sorteringen afviste billedet: \(s)"
        case .network(let e): return "Netværksfejl: \(e.localizedDescription)"
        }
    }
}
