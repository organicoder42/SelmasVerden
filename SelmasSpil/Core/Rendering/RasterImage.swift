import Foundation
import CoreGraphics

/// Et billede som rå RGBA-bytes (8 bit, premultipliceret alpha), så vi kan lave flood fill og
/// pixel-arbejde hurtigt uden at gå igennem Core Image.
struct RasterImage: Sendable {
    let width: Int
    let height: Int
    var pixels: [UInt8] // RGBA, rækkevis, premultipliceret

    static let bitmapInfo: UInt32 = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue

    init(width: Int, height: Int, pixels: [UInt8]) {
        precondition(pixels.count == width * height * 4)
        self.width = width
        self.height = height
        self.pixels = pixels
    }

    init(width: Int, height: Int) {
        self.width = width
        self.height = height
        self.pixels = [UInt8](repeating: 0, count: width * height * 4)
    }

    init?(cgImage: CGImage) {
        let w = cgImage.width, h = cgImage.height
        guard w > 0, h > 0 else { return nil }
        var buffer = [UInt8](repeating: 0, count: w * h * 4)
        let ok = buffer.withUnsafeMutableBytes { ptr -> Bool in
            guard let ctx = CGContext(data: ptr.baseAddress, width: w, height: h, bitsPerComponent: 8,
                                      bytesPerRow: w * 4, space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: RasterImage.bitmapInfo) else { return false }
            ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: w, height: h))
            return true
        }
        guard ok else { return nil }
        self.width = w
        self.height = h
        self.pixels = buffer
    }

    func cgImage() -> CGImage? {
        let data = Data(pixels)
        guard let provider = CGDataProvider(data: data as CFData) else { return nil }
        return CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4,
                       space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGBitmapInfo(rawValue: RasterImage.bitmapInfo),
                       provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
    }

    @inline(__always) func index(_ x: Int, _ y: Int) -> Int { (y * width + x) * 4 }

    @inline(__always) func alpha(_ x: Int, _ y: Int) -> UInt8 { pixels[index(x, y) + 3] }

    @inline(__always) func contains(_ x: Int, _ y: Int) -> Bool { x >= 0 && y >= 0 && x < width && y < height }

    /// Luminans 0...255 af den u-premultiplicerede farve (så gennemsigtige kanter ikke ser sorte ud).
    @inline(__always) func luminance(at i: Int) -> Int {
        let a = Int(pixels[i + 3])
        guard a > 0 else { return 255 }
        let r = Int(pixels[i]) * 255 / a, g = Int(pixels[i + 1]) * 255 / a, b = Int(pixels[i + 2]) * 255 / a
        return (r * 299 + g * 587 + b * 114) / 1000
    }

    /// Mindste rektangel der indeholder alle pixels med alpha over `threshold`. Nil hvis billedet er tomt.
    func opaqueBounds(threshold: UInt8 = 8) -> (x: Int, y: Int, width: Int, height: Int)? {
        var minX = width, minY = height, maxX = -1, maxY = -1
        for y in 0..<height {
            let row = y * width * 4
            for x in 0..<width where pixels[row + x * 4 + 3] > threshold {
                if x < minX { minX = x }
                if x > maxX { maxX = x }
                if y < minY { minY = y }
                if y > maxY { maxY = y }
            }
        }
        guard maxX >= minX, maxY >= minY else { return nil }
        return (minX, minY, maxX - minX + 1, maxY - minY + 1)
    }

    func cropped(x: Int, y: Int, width w: Int, height h: Int) -> RasterImage {
        let x0 = max(0, x), y0 = max(0, y)
        let x1 = min(width, x + w), y1 = min(height, y + h)
        let nw = max(0, x1 - x0), nh = max(0, y1 - y0)
        var out = RasterImage(width: nw, height: nh)
        guard nw > 0, nh > 0 else { return out }
        for row in 0..<nh {
            let src = ((y0 + row) * width + x0) * 4
            let dst = row * nw * 4
            out.pixels.replaceSubrange(dst..<(dst + nw * 4), with: pixels[src..<(src + nw * 4)])
        }
        return out
    }

    /// Hurtig nearest-neighbour-skalering (til arbejdskopier og mønster-fliser).
    func resized(width nw: Int, height nh: Int) -> RasterImage {
        guard nw > 0, nh > 0, width > 0, height > 0 else { return RasterImage(width: max(1, nw), height: max(1, nh)) }
        var out = RasterImage(width: nw, height: nh)
        for y in 0..<nh {
            let sy = min(height - 1, y * height / nh)
            for x in 0..<nw {
                let sx = min(width - 1, x * width / nw)
                let s = index(sx, sy), d = out.index(x, y)
                out.pixels[d] = pixels[s]; out.pixels[d + 1] = pixels[s + 1]
                out.pixels[d + 2] = pixels[s + 2]; out.pixels[d + 3] = pixels[s + 3]
            }
        }
        return out
    }
}
