import SwiftUI

/// Tegner en figur lag for lag: krop, strømper, sko, bukser, kjole, trøje, ansigt, hår, hat ...
/// Alt skaleres ud fra kroppens billede, så figuren kan vises i alle størrelser.
struct CharacterView: View {
    @Environment(AppModel.self) private var model
    let character: GameCharacter
    var selectedSlot: WearableSlot? = nil
    var highlight: Bool = false

    var body: some View {
        GeometryReader { geo in
            let body = model.library.asset(id: character.bodyAssetID)
            let bodyRect = Self.bodyRect(in: geo.size, aspect: body?.aspectRatio ?? 0.5)
            ZStack {
                ForEach(character.layers) { layer in
                    let asset = model.library.asset(id: layer.assetID)
                    let fit = Rig.fit(for: layer, asset: asset, body: body)
                    let h = bodyRect.height * fit.heightRatio
                    let w = h * (asset?.aspectRatio ?? 1)
                    if let img = model.renderer.image(for: layer.assetID, paint: layer.paint) {
                        Image(decorative: img, scale: 1)
                            .resizable()
                            .frame(width: w, height: h)
                            .rotationEffect(.radians(fit.rotation))
                            .position(x: bodyRect.minX + fit.center.x * bodyRect.width,
                                      y: bodyRect.minY + fit.center.y * bodyRect.height)
                            .opacity(selectedSlot == nil || selectedSlot == layer.slot || layer.slot == nil ? 1 : 0.45)
                    }
                }
            }
        }
    }

    /// Kroppen fylder så meget af rammen som muligt, centreret.
    static func bodyRect(in size: CGSize, aspect: CGFloat) -> CGRect {
        guard size.width > 0, size.height > 0 else { return .zero }
        var h = size.height * 0.92
        var w = h * aspect
        if w > size.width * 0.92 {
            w = size.width * 0.92
            h = w / max(0.01, aspect)
        }
        return CGRect(x: (size.width - w) / 2, y: (size.height - h) / 2, width: w, height: h)
    }
}
