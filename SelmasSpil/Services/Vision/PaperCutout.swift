import Foundation
import CoreGraphics

/// Fjerner papiret bag en tegning, så kun stregerne og farverne bliver tilbage med gennemsigtig baggrund.
/// Virker på fotos med ujævnt lys ved at måle papirets lysstyrke lokalt i stedet for globalt.
enum PaperCutout {

    struct Options: Sendable {
        /// Hvor meget mørkere end papiret en pixel skal være for at regnes som streg (0...255).
        var darknessMargin: Int = 28
        /// Hvor farvet en pixel skal være for at regnes som farvelægning selv om den er lys (0...255).
        var saturationMargin: Int = 38
        /// Størrelse på de lokale felter papiret måles i (pixels). Større = mere robust, mindre = følger skygger bedre.
        var cellSize: Int = 64
        /// Blød kant: alpha stiger fra 0 til 255 over dette interval.
        var softness: Int = 24
        static let `default` = Options()
    }

    /// Returnerer et nyt billede hvor papiret er gennemsigtigt.
    static func cutout(_ image: RasterImage, options: Options = .default) -> RasterImage {
        let w = image.width, h = image.height
        guard w > 0, h > 0 else { return image }
        var out = image

        // 1) Mål papirets lysstyrke pr. felt (90. percentil - papiret er det lyseste i feltet)
        let cell = max(16, options.cellSize)
        let cols = (w + cell - 1) / cell, rows = (h + cell - 1) / cell
        var paper = [Int](repeating: 255, count: cols * rows)
        var hist = [Int](repeating: 0, count: 256)
        for cy in 0..<rows {
            for cx in 0..<cols {
                for k in 0..<256 { hist[k] = 0 }
                var n = 0
                let y0 = cy * cell, y1 = min(h, y0 + cell)
                let x0 = cx * cell, x1 = min(w, x0 + cell)
                var y = y0
                while y < y1 {
                    var x = x0
                    while x < x1 {
                        hist[image.luminance(at: image.index(x, y))] += 1
                        n += 1
                        x += 2
                    }
                    y += 2
                }
                var acc = 0, p = 255
                let target = n * 90 / 100
                for k in 0..<256 {
                    acc += hist[k]
                    if acc >= target { p = k; break }
                }
                paper[cy * cols + cx] = p
            }
        }
        // Glat papirkortet så feltgrænser ikke giver kanter
        var smooth = paper
        for cy in 0..<rows {
            for cx in 0..<cols {
                var s = 0, n = 0
                for dy in -1...1 {
                    for dx in -1...1 {
                        let ny = cy + dy, nx = cx + dx
                        if ny >= 0, ny < rows, nx >= 0, nx < cols { s += paper[ny * cols + nx]; n += 1 }
                    }
                }
                smooth[cy * cols + cx] = s / max(1, n)
            }
        }

        // 2) Alpha pr. pixel ud fra mørke og mætning i forhold til det lokale papir
        let soft = max(1, options.softness)
        for y in 0..<h {
            let cy = min(rows - 1, y / cell)
            for x in 0..<w {
                let i = image.index(x, y)
                let a = Int(image.pixels[i + 3])
                if a == 0 { continue }
                let r = Int(image.pixels[i]) * 255 / a, g = Int(image.pixels[i + 1]) * 255 / a, b = Int(image.pixels[i + 2]) * 255 / a
                let lum = (r * 299 + g * 587 + b * 114) / 1000
                let sat = max(r, g, b) - min(r, g, b)
                let p = smooth[cy * cols + min(cols - 1, x / cell)]
                let darkness = p - lum - options.darknessMargin
                let colorful = sat - options.saturationMargin
                let score = max(darkness, colorful) // hvor "tegnet" pixelen er
                var alpha = 255
                if score < 0 {
                    alpha = 0
                } else if score < soft {
                    alpha = score * 255 / soft
                }
                let na = alpha * a / 255
                out.pixels[i] = UInt8(clamping: r * na / 255)
                out.pixels[i + 1] = UInt8(clamping: g * na / 255)
                out.pixels[i + 2] = UInt8(clamping: b * na / 255)
                out.pixels[i + 3] = UInt8(clamping: na)
            }
        }

        // 3) Fjern enlige støj-pixels (papirkorn, der slap igennem)
        despeckle(&out)
        return out
    }

    /// Sætter alpha til 0 for pixels der ikke har mindst 2 synlige naboer.
    static func despeckle(_ image: inout RasterImage) {
        let w = image.width, h = image.height
        let src = image.pixels
        for y in 1..<(h - 1) {
            for x in 1..<(w - 1) {
                let i = (y * w + x) * 4
                guard src[i + 3] > 0 else { continue }
                var n = 0
                for dy in -1...1 {
                    for dx in -1...1 where dx != 0 || dy != 0 {
                        if src[((y + dy) * w + (x + dx)) * 4 + 3] > 40 { n += 1 }
                    }
                }
                if n < 2 {
                    image.pixels[i] = 0; image.pixels[i + 1] = 0; image.pixels[i + 2] = 0; image.pixels[i + 3] = 0
                }
            }
        }
    }
}
