import Foundation
import CoreGraphics

/// Giver det færdige billede af en tegning med dens maling. Cacher på (asset, maling), så
/// rum med mange ting ikke regner flood fill hver frame.
@MainActor
final class AssetRenderer {
    private let library: AssetLibrary
    private let cache = NSCache<NSString, CGImageBox>()

    init(library: AssetLibrary) {
        self.library = library
        cache.countLimit = 300
    }

    func image(for assetID: UUID, paint: PaintState) -> CGImage? {
        guard let asset = library.asset(id: assetID), let base = library.image(for: asset) else { return nil }
        guard !paint.isEmpty else { return base }
        let key = "\(assetID.uuidString)|\(paint.hashValue)" as NSString
        if let hit = cache.object(forKey: key) { return hit.image }
        let rendered = PaintEngine.render(base: base, paint: paint) { [library] pid in
            library.image(forAssetID: pid)
        }
        if let rendered {
            cache.setObject(CGImageBox(rendered), forKey: key)
        }
        return rendered
    }

    func invalidate() {
        cache.removeAllObjects()
    }
}
