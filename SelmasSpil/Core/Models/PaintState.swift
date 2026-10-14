import Foundation
import CoreGraphics

/// Alt det et barn har gjort ved en tegning med malerspanden: en liste af fyld, i rækkefølge.
/// Vi gemmer kun handlingerne, ikke det færdige billede - så det kan altid genskabes og fortrydes.
struct PaintState: Codable, Hashable, Sendable {
    var fills: [RegionFill] = []

    var isEmpty: Bool { fills.isEmpty }

    mutating func undo() {
        _ = fills.popLast()
    }

    mutating func add(_ fill: RegionFill) {
        fills.append(fill)
    }

    static let none = PaintState()
}

struct RegionFill: Codable, Hashable, Sendable {
    /// Punktet man trykkede på, normaliseret 0...1 i tegningens billede.
    var seed: CGPoint
    var style: FillStyle
}

enum FillStyle: Codable, Hashable, Sendable {
    case color(RGBA)
    /// Et mønster (en anden tegning af kategori `pattern`) flisebelagt over området.
    /// `scale` er flisens højde som andel af tegningens højde. `background` fylder bag mønsteret.
    case pattern(assetID: UUID, scale: CGFloat, background: RGBA?)
}

struct RGBA: Codable, Hashable, Sendable {
    var r: Double
    var g: Double
    var b: Double
    var a: Double

    init(r: Double, g: Double, b: Double, a: Double = 1) {
        self.r = r; self.g = g; self.b = b; self.a = a
    }

    /// "#RRGGBB" eller "#RRGGBBAA"
    init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6 || s.count == 8, let value = UInt64(s, radix: 16) else { return nil }
        if s.count == 6 {
            r = Double((value >> 16) & 0xFF) / 255
            g = Double((value >> 8) & 0xFF) / 255
            b = Double(value & 0xFF) / 255
            a = 1
        } else {
            r = Double((value >> 24) & 0xFF) / 255
            g = Double((value >> 16) & 0xFF) / 255
            b = Double((value >> 8) & 0xFF) / 255
            a = Double(value & 0xFF) / 255
        }
    }

    var hex: String {
        String(format: "#%02X%02X%02X", Int(round(r * 255)), Int(round(g * 255)), Int(round(b * 255)))
    }

    var bytes: (r: UInt8, g: UInt8, b: UInt8, a: UInt8) {
        (UInt8(clamping: Int(round(r * 255))), UInt8(clamping: Int(round(g * 255))),
         UInt8(clamping: Int(round(b * 255))), UInt8(clamping: Int(round(a * 255))))
    }

    static let white = RGBA(r: 1, g: 1, b: 1)
    static let black = RGBA(r: 0, g: 0, b: 0)
}
