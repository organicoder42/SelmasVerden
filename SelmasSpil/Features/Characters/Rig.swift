import Foundation
import CoreGraphics

/// Standard-placering af pladser på en krop, når kroppen ikke selv har ankre (fra AI'en eller forælderen).
/// Alt er normaliseret til kroppens billede: (0,0) øverst til venstre, (1,1) nederst til højre.
enum Rig {
    static func defaultFit(for slot: WearableSlot) -> AssetFit {
        switch slot {
        case .hat: return AssetFit(center: CGPoint(x: 0.5, y: 0.05), heightRatio: 0.16)
        case .hair: return AssetFit(center: CGPoint(x: 0.5, y: 0.10), heightRatio: 0.26)
        case .eyebrows: return AssetFit(center: CGPoint(x: 0.5, y: 0.14), heightRatio: 0.03)
        case .eyes: return AssetFit(center: CGPoint(x: 0.5, y: 0.17), heightRatio: 0.06)
        case .glasses: return AssetFit(center: CGPoint(x: 0.5, y: 0.17), heightRatio: 0.08)
        case .ears: return AssetFit(center: CGPoint(x: 0.5, y: 0.18), heightRatio: 0.08)
        case .nose: return AssetFit(center: CGPoint(x: 0.5, y: 0.21), heightRatio: 0.04)
        case .mouth: return AssetFit(center: CGPoint(x: 0.5, y: 0.25), heightRatio: 0.04)
        case .beard: return AssetFit(center: CGPoint(x: 0.5, y: 0.29), heightRatio: 0.10)
        case .handLeft: return AssetFit(center: CGPoint(x: 0.14, y: 0.56), heightRatio: 0.08)
        case .handRight: return AssetFit(center: CGPoint(x: 0.86, y: 0.56), heightRatio: 0.08)
        case .accessory: return AssetFit(center: CGPoint(x: 0.5, y: 0.35), heightRatio: 0.10)
        case .top: return AssetFit(center: CGPoint(x: 0.5, y: 0.47), heightRatio: 0.30)
        case .jacket: return AssetFit(center: CGPoint(x: 0.5, y: 0.47), heightRatio: 0.33)
        case .dress: return AssetFit(center: CGPoint(x: 0.5, y: 0.58), heightRatio: 0.52)
        case .bag: return AssetFit(center: CGPoint(x: 0.78, y: 0.52), heightRatio: 0.18)
        case .bottom: return AssetFit(center: CGPoint(x: 0.5, y: 0.70), heightRatio: 0.34)
        case .socks: return AssetFit(center: CGPoint(x: 0.5, y: 0.90), heightRatio: 0.10)
        case .shoes: return AssetFit(center: CGPoint(x: 0.5, y: 0.95), heightRatio: 0.09)
        }
    }

    /// Den endelige placering af en del på en given krop:
    /// 1) barnets egen justering, 2) delens gemte pasform, 3) kroppens anker + standardhøjde, 4) standard.
    static func fit(for layer: CharacterLayer, asset: DrawingAsset?, body: DrawingAsset?) -> AssetFit {
        guard let slot = layer.slot else {
            return AssetFit(center: CGPoint(x: 0.5, y: 0.5), heightRatio: 1)
        }
        if let f = layer.fitOverride { return f }
        if let f = asset?.fit { return f }
        var f = defaultFit(for: slot)
        if let anchor = body?.anchors?[slot.rawValue] {
            f.center = anchor
        }
        return f
    }
}
