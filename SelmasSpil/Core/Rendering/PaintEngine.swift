import Foundation
import CoreGraphics

/// Malerspanden. Finder det sammenhængende område omkring et punkt (afgrænset af Selmas konturer og
/// af farveskift) og fylder det med en farve eller et mønster - mens blyantens tekstur bevares.
///
/// Tegningerne er klippet ud af papiret (`PaperCutout`), så indersiden af en kuglepens-tegning er
/// gennemsigtig. Fyldet løber derfor hen over gennemsigtigt "papir" og stopper ved blæk. Et område der
/// rører billedets kant er "udenfor tegningen" og fyldes ikke. Små huller i omridset lukkes ved at
/// blækmasken udvides lidt før fyldet.
enum PaintEngine {

    struct Options: Sendable {
        /// Hvor forskellig en nabo-pixel må være (sum af |ΔR|+|ΔG|+|ΔB|, 0...765) og stadig regnes med i området.
        var colorTolerance: Int = 110
        /// Pixels mørkere end dette (og ikke farvede, se `inkSaturation`) regnes som streg og stopper altid fyldet
        /// (med mindre man trykker på stregen). Kuglepen og blyant på et foto ender typisk på lysstyrke 60-160.
        var inkLuminance: Int = 170
        /// Pixels mere farvemættede end dette (max(RGB) - min(RGB)) er farvelægning, ikke streg, uanset lysstyrke.
        var inkSaturation: Int = 70
        /// Pixels med alpha under dette er gennemsigtigt papir.
        var alphaThreshold: UInt8 = 24
        /// Hvor meget af blyantteksturen beholdes. 0 = fladt, 1 = fuld tekstur.
        var textureKeep: Double = 0.55
        /// Så mange pixels udvides blækket før fyldet, så huller i omridset op til det dobbelte lukkes.
        var gapClose: Int = 2
        /// Lækker fyldet ud, øges lukningen trinvist op til denne (huller op til det dobbelte lukkes).
        var maxGapClose: Int = 8

        static let `default` = Options()
    }

    /// Værdier i masken fra `region`.
    enum MaskValue {
        /// Ikke i området.
        static let outside: UInt8 = 0
        /// Opak pixel (farvelægning eller blæk) der skal farves om, med tekstur og uændret alpha.
        static let recolor: UInt8 = 1
        /// Papir eller blød stregkant: fyldet lægges *bagved* det der er, og pixelen bliver opak.
        static let fillBehind: UInt8 = 2
    }

    // MARK: - Område

    /// Returnerer en maske (se `MaskValue`) med samme størrelse som billedet, eller nil hvis der ikke er
    /// noget at fylde (udenfor billedet, eller et åbent område der løber ud over kanten).
    static func region(in image: RasterImage, seedX: Int, seedY: Int, options: Options = .default) -> [UInt8]? {
        guard image.contains(seedX, seedY) else { return nil }
        let w = image.width, h = image.height
        let si = image.index(seedX, seedY)
        let seedIsPaper = image.pixels[si + 3] < options.alphaThreshold
        let seedIsInk = !seedIsPaper && isInk(image, si, options)

        // Sammenlign på u-premultiplicerede farver
        @inline(__always) func rgb(_ i: Int) -> (Int, Int, Int) {
            let a = Int(image.pixels[i + 3])
            guard a > 0 else { return (255, 255, 255) }
            return (Int(image.pixels[i]) * 255 / a, Int(image.pixels[i + 1]) * 255 / a, Int(image.pixels[i + 2]) * 255 / a)
        }
        let (sr, sg, sb) = rgb(si)
        @inline(__always) func colorClose(_ i: Int) -> Bool {
            let (r, g, b) = rgb(i)
            return abs(r - sr) + abs(g - sg) + abs(b - sb) <= options.colorTolerance
        }

        // Tryk på selve stregen: farv de sammenhængende streg-pixels om (ingen papir, ingen hul-lukning).
        if seedIsInk {
            let (mask, _) = flood(image, seed: seedY * w + seedX) { p in
                let i = p * 4
                return image.pixels[i + 3] >= options.alphaThreshold && colorClose(i) ? MaskValue.recolor : MaskValue.outside
            }
            return mask
        }

        // Blæk, udvidet så småhuller i omridset lukkes
        var ink = [Bool](repeating: false, count: w * h)
        for p in 0..<(w * h) {
            let i = p * 4
            ink[p] = image.pixels[i + 3] >= options.alphaThreshold && isInk(image, i, options)
        }
        func classify(includePaper: Bool, barrier: [Bool]) -> (Int) -> UInt8 {
            { p in
                if barrier[p] { return MaskValue.outside }
                let i = p * 4
                if image.pixels[i + 3] < options.alphaThreshold { return includePaper ? MaskValue.fillBehind : MaskValue.outside }
                return !seedIsPaper && colorClose(i) ? MaskValue.recolor : MaskValue.outside
            }
        }

        // Prøv med lille hul-lukning først (så smalle områder som ører og fingre stadig kan fyldes). Løber
        // fyldet ud af tegningen, er der et hul i omridset - så prøves der med større lukning, op til maks.
        var mask: [UInt8] = []
        var gapClose = options.gapClose
        var closed = false
        while gapClose <= options.maxGapClose {
            let barrier = dilated(ink, width: w, height: h, radius: gapClose)
            let classify = classify(includePaper: true, barrier: barrier)
            // Ligger trykpunktet i den udvidede blækzone (tæt på en streg), startes fra nærmeste frie pixel.
            // Søgeradius passer med udvidelsen, så vi aldrig hopper over på den anden side af en streg.
            guard let start = nearest(to: seedX, seedY, within: gapClose + 1, width: w, height: h,
                                      where: { classify($0) != MaskValue.outside }) else {
                gapClose += 2
                continue
            }
            let (m, touchesEdge) = flood(image, seed: start, classify: classify)
            if !touchesEdge {
                mask = m
                closed = true
                break
            }
            gapClose += 2
        }
        if !closed {
            // Området løber ud af tegningen selv med stor hul-lukning. Trykkede man på papir, er der intet at
            // fylde; trykkede man på en farvelægning uden omrids, farves kun selve farvelægningen om.
            guard !seedIsPaper else { return nil }
            (mask, _) = flood(image, seed: seedY * w + seedX, classify: classify(includePaper: false, barrier: ink))
            return mask
        }

        // Lad fyldet kravle ind i den udvidede blækzone og under de bløde stregkanter, så der ikke står en
        // bræmme mellem farven og stregen. Rækkevidden passer med udvidelsen, så fyldet aldrig når ud på
        // den anden side af en streg.
        let reach = dilated(mask.map { $0 != MaskValue.outside }, width: w, height: h, radius: gapClose + 1)
        for p in 0..<(w * h) where mask[p] == MaskValue.outside && reach[p] {
            let i = p * 4
            if image.pixels[i + 3] < 255 {
                mask[p] = MaskValue.fillBehind // også bløde, halvgennemsigtige stregkanter
            } else if !ink[p] && !seedIsPaper && colorClose(i) {
                mask[p] = MaskValue.recolor
            }
        }
        return mask
    }

    /// Er pixelen (byte-indeks `i`) en tegnet streg: mørk nok og ikke farvet?
    @inline(__always)
    private static func isInk(_ image: RasterImage, _ i: Int, _ options: Options) -> Bool {
        guard image.luminance(at: i) < options.inkLuminance else { return false }
        let a = Int(image.pixels[i + 3])
        guard a > 0 else { return false }
        let r = Int(image.pixels[i]) * 255 / a, g = Int(image.pixels[i + 1]) * 255 / a, b = Int(image.pixels[i + 2]) * 255 / a
        return max(r, g, b) - min(r, g, b) < options.inkSaturation
    }

    /// Nærmeste pixel (i voksende kvadrater) omkring (x, y) der opfylder betingelsen. Punktet selv tjekkes først.
    private static func nearest(to x: Int, _ y: Int, within radius: Int, width w: Int, height h: Int,
                                where ok: (Int) -> Bool) -> Int? {
        if ok(y * w + x) { return y * w + x }
        for r in 1...max(1, radius) {
            for ny in max(0, y - r)...min(h - 1, y + r) {
                let edgeRow = ny == y - r || ny == y + r
                var nx = max(0, x - r)
                while nx <= min(w - 1, x + r) {
                    if ok(ny * w + nx) { return ny * w + nx }
                    nx += edgeRow ? 1 : 2 * r
                }
            }
        }
        return nil
    }

    /// Scanline flood fill. `classify` giver maskeværdien for en pixel (0 = stop). Returnerer også om
    /// området rører billedets kant.
    private static func flood(_ image: RasterImage, seed: Int, classify: (Int) -> UInt8) -> (mask: [UInt8], touchesEdge: Bool) {
        let w = image.width, h = image.height
        var mask = [UInt8](repeating: MaskValue.outside, count: w * h)
        var touchesEdge = false
        var stack: [Int] = [seed]
        stack.reserveCapacity(4096)

        while let p = stack.popLast() {
            if mask[p] != MaskValue.outside { continue }
            let v = classify(p)
            if v == MaskValue.outside { continue }
            let y = p / w
            var x0 = p % w
            var x1 = x0
            mask[p] = v
            while x0 > 0, mask[y * w + x0 - 1] == MaskValue.outside {
                let q = y * w + x0 - 1
                let qv = classify(q)
                if qv == MaskValue.outside { break }
                mask[q] = qv
                x0 -= 1
            }
            while x1 < w - 1, mask[y * w + x1 + 1] == MaskValue.outside {
                let q = y * w + x1 + 1
                let qv = classify(q)
                if qv == MaskValue.outside { break }
                mask[q] = qv
                x1 += 1
            }
            if x0 == 0 || x1 == w - 1 || y == 0 || y == h - 1 { touchesEdge = true }
            for ny in [y - 1, y + 1] where ny >= 0 && ny < h {
                var x = x0
                var inRun = false
                while x <= x1 {
                    let q = ny * w + x
                    let open = mask[q] == MaskValue.outside && classify(q) != MaskValue.outside
                    if open && !inRun { stack.append(q) }
                    inRun = open
                    x += 1
                }
            }
        }
        return (mask, touchesEdge)
    }

    /// Udvider sande pixels med `radius` i alle retninger (kvadratisk nabolag), separabelt.
    private static func dilated(_ src: [Bool], width w: Int, height h: Int, radius r: Int) -> [Bool] {
        guard r > 0 else { return src }
        var tmp = [Bool](repeating: false, count: w * h)
        for y in 0..<h {
            let row = y * w
            for x in 0..<w where src[row + x] {
                for nx in max(0, x - r)...min(w - 1, x + r) { tmp[row + nx] = true }
            }
        }
        var out = [Bool](repeating: false, count: w * h)
        for y in 0..<h {
            let row = y * w
            for x in 0..<w where tmp[row + x] {
                for ny in max(0, y - r)...min(h - 1, y + r) { out[ny * w + x] = true }
            }
        }
        return out
    }

    // MARK: - Fyld

    /// Fylder området med en farve. Opake pixels farves om med blyant-teksturen bevaret (farven ganges med
    /// pixelens relative lysstyrke i forhold til områdets gennemsnit). Papir og bløde stregkanter får farven
    /// lagt bagved, så stregen bliver stående ovenpå.
    static func fill(_ image: inout RasterImage, mask: [UInt8], color: RGBA, options: Options = .default) {
        let (cr, cg, cb, _) = color.bytes
        let avg = averageLuminance(image, mask: mask)
        let keep = options.textureKeep
        for p in 0..<mask.count where mask[p] != MaskValue.outside {
            let i = p * 4
            let a = Int(image.pixels[i + 3])
            if mask[p] == MaskValue.fillBehind {
                // destination-over: det der er, bliver stående ovenpå farven
                let rest = 255 - a
                image.pixels[i] = UInt8(clamping: Int(image.pixels[i]) + Int(cr) * rest / 255)
                image.pixels[i + 1] = UInt8(clamping: Int(image.pixels[i + 1]) + Int(cg) * rest / 255)
                image.pixels[i + 2] = UInt8(clamping: Int(image.pixels[i + 2]) + Int(cb) * rest / 255)
                image.pixels[i + 3] = 255
                continue
            }
            guard a > 0 else { continue }
            let lum = Double(image.luminance(at: i))
            // relativ lysstyrke 0.6...1.15, afdæmpet af textureKeep
            var f = 1.0
            if avg > 0 {
                f = 1 + (lum / avg - 1) * keep
                f = min(1.15, max(0.6, f))
            }
            image.pixels[i] = UInt8(clamping: Int(Double(cr) * f) * a / 255)
            image.pixels[i + 1] = UInt8(clamping: Int(Double(cg) * f) * a / 255)
            image.pixels[i + 2] = UInt8(clamping: Int(Double(cb) * f) * a / 255)
        }
    }

    /// Fylder området med et mønster, flisebelagt. `tileHeight` i pixels i målbilledet.
    static func fill(_ image: inout RasterImage, mask: [UInt8], pattern: RasterImage, tileHeight: Int,
                     background: RGBA?, options: Options = .default) {
        guard pattern.width > 0, pattern.height > 0 else { return }
        let th = max(4, tileHeight)
        let tw = max(4, pattern.width * th / pattern.height)
        let tile = pattern.resized(width: tw, height: th)
        if let background {
            fill(&image, mask: mask, color: background, options: options)
        }
        let w = image.width
        for p in 0..<mask.count where mask[p] != MaskValue.outside {
            let i = p * 4
            let x = p % w, y = p / w
            let ti = tile.index(x % tw, y % th)
            let cov = Int(tile.pixels[ti + 3])
            guard cov > 40 else { continue }
            // u-premultiplicér mønsterets farve
            let pr = Int(tile.pixels[ti]) * 255 / cov, pg = Int(tile.pixels[ti + 1]) * 255 / cov, pb = Int(tile.pixels[ti + 2]) * 255 / cov
            let a = Int(image.pixels[i + 3])
            if mask[p] == MaskValue.fillBehind && background == nil {
                // Mønsteret lægges bagved det der er (streg-kanter), med sin egen dækning
                let rest = 255 - a
                image.pixels[i] = UInt8(clamping: Int(image.pixels[i]) + pr * cov / 255 * rest / 255)
                image.pixels[i + 1] = UInt8(clamping: Int(image.pixels[i + 1]) + pg * cov / 255 * rest / 255)
                image.pixels[i + 2] = UInt8(clamping: Int(image.pixels[i + 2]) + pb * cov / 255 * rest / 255)
                image.pixels[i + 3] = UInt8(clamping: a + cov * rest / 255)
                continue
            }
            guard a > 0 else { continue }
            // Mønsteret lægges ovenpå den eksisterende farve med sin egen dækning
            let br = Int(image.pixels[i]), bg = Int(image.pixels[i + 1]), bb = Int(image.pixels[i + 2])
            image.pixels[i] = UInt8(clamping: (pr * a / 255 * cov + br * (255 - cov)) / 255)
            image.pixels[i + 1] = UInt8(clamping: (pg * a / 255 * cov + bg * (255 - cov)) / 255)
            image.pixels[i + 2] = UInt8(clamping: (pb * a / 255 * cov + bb * (255 - cov)) / 255)
        }
    }

    /// Gennemsnitlig lysstyrke af de opake pixels der skal farves om (papir tæller ikke med).
    private static func averageLuminance(_ image: RasterImage, mask: [UInt8]) -> Double {
        var sum = 0, n = 0
        var p = 0
        while p < mask.count {
            if mask[p] == MaskValue.recolor {
                sum += image.luminance(at: p * 4)
                n += 1
            }
            p += 7 // sampling er rigeligt til et gennemsnit
        }
        return n == 0 ? 0 : Double(sum) / Double(n)
    }

    // MARK: - Afspil en hel PaintState

    /// Genskaber det malede billede ud fra originalen og listen af fyld.
    static func render(base: CGImage, paint: PaintState, patternProvider: (UUID) -> CGImage?,
                       options: Options = .default) -> CGImage? {
        guard !paint.isEmpty else { return base }
        guard var raster = RasterImage(cgImage: base) else { return nil }
        for fill in paint.fills {
            let sx = Int((fill.seed.x * CGFloat(raster.width)).rounded(.down))
            let sy = Int((fill.seed.y * CGFloat(raster.height)).rounded(.down))
            guard let mask = region(in: raster, seedX: sx, seedY: sy, options: options) else { continue }
            switch fill.style {
            case .color(let c):
                PaintEngine.fill(&raster, mask: mask, color: c, options: options)
            case .pattern(let assetID, let scale, let background):
                guard let pcg = patternProvider(assetID), let pr = RasterImage(cgImage: pcg) else { continue }
                let tileHeight = Int(CGFloat(raster.height) * scale)
                PaintEngine.fill(&raster, mask: mask, pattern: pr, tileHeight: tileHeight, background: background, options: options)
            }
        }
        return raster.cgImage()
    }
}
