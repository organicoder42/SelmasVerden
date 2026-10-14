import Foundation
import CoreGraphics

/// Deler et udskåret ark op i de enkelte tegninger (sammenhængende områder), så fire stykker tøj
/// på ét stykke papir bliver til fire assets. Små, nære stumper (øjne, knapper) slås sammen med
/// den tegning de hører til.
enum ComponentSplitter {

    struct Piece: Sendable {
        var image: RasterImage
        /// Placering i det oprindelige ark (pixels).
        var rect: CGRect
        var pixelCount: Int
    }

    struct Options: Sendable {
        /// Komponenter mindre end denne andel af arkets areal smides ud som støj.
        var minAreaFraction: Double = 0.0008
        /// Komponenter hvis bokse ligger tættere end denne andel af arkets længste side slås sammen.
        var mergeDistanceFraction: Double = 0.025
        /// Luft omkring hver udskåret del, andel af delens størrelse.
        var padding: Double = 0.06
        var alphaThreshold: UInt8 = 40
        static let `default` = Options()
    }

    static func split(_ image: RasterImage, options: Options = .default) -> [Piece] {
        let w = image.width, h = image.height
        guard w > 0, h > 0 else { return [] }

        // 1) Mærk sammenhængende områder (8-forbundet)
        var labels = [Int32](repeating: 0, count: w * h)
        var boxes: [(minX: Int, minY: Int, maxX: Int, maxY: Int, count: Int)] = []
        var stack: [Int] = []
        var next: Int32 = 1
        for start in 0..<(w * h) {
            guard labels[start] == 0, image.pixels[start * 4 + 3] >= options.alphaThreshold else { continue }
            var box = (minX: w, minY: h, maxX: -1, maxY: -1, count: 0)
            labels[start] = next
            stack.append(start)
            while let p = stack.popLast() {
                let x = p % w, y = p / w
                box.count += 1
                if x < box.minX { box.minX = x }
                if x > box.maxX { box.maxX = x }
                if y < box.minY { box.minY = y }
                if y > box.maxY { box.maxY = y }
                for dy in -1...1 {
                    let ny = y + dy
                    guard ny >= 0, ny < h else { continue }
                    for dx in -1...1 where dx != 0 || dy != 0 {
                        let nx = x + dx
                        guard nx >= 0, nx < w else { continue }
                        let q = ny * w + nx
                        if labels[q] == 0, image.pixels[q * 4 + 3] >= options.alphaThreshold {
                            labels[q] = next
                            stack.append(q)
                        }
                    }
                }
            }
            boxes.append(box)
            next += 1
        }

        // 2) Smid kun ægte støj ud (enkelte korn). Små dele som prikker og øjne beholdes,
        //    så de kan slås sammen med det de hører til i næste trin.
        let noiseArea = max(6, Int(Double(w * h) * options.minAreaFraction * 0.08))
        var groups: [[Int]] = []
        for (i, b) in boxes.enumerated() where b.count >= noiseArea {
            groups.append([i])
        }
        guard !groups.isEmpty else { return [] }

        // 3) Slå nære bokse sammen (union-find over udvidede bokse)
        let margin = Int(Double(max(w, h)) * options.mergeDistanceFraction)
        func unionBox(_ g: [Int]) -> (Int, Int, Int, Int) {
            var r = (w, h, -1, -1)
            for i in g {
                r.0 = min(r.0, boxes[i].minX); r.1 = min(r.1, boxes[i].minY)
                r.2 = max(r.2, boxes[i].maxX); r.3 = max(r.3, boxes[i].maxY)
            }
            return r
        }
        var merged = true
        while merged {
            merged = false
            outer: for a in 0..<groups.count {
                for b in (a + 1)..<groups.count {
                    let ba = unionBox(groups[a]), bb = unionBox(groups[b])
                    let overlap = ba.0 - margin <= bb.2 && bb.0 - margin <= ba.2 && ba.1 - margin <= bb.3 && bb.1 - margin <= ba.3
                    if overlap {
                        groups[a].append(contentsOf: groups[b])
                        groups.remove(at: b)
                        merged = true
                        break outer
                    }
                }
            }
        }

        // 4) Grupper der samlet er for små er støj (fx en enkelt prik langt fra alt andet)
        let minArea = Int(Double(w * h) * options.minAreaFraction)
        groups = groups.filter { g in g.reduce(0) { $0 + boxes[$1].count } >= minArea }

        // 5) Skær ud - kun pixels der hører til gruppens komponenter, så nabo-tegninger ikke kommer med
        var pieces: [Piece] = []
        for g in groups {
            let (minX, minY, maxX, maxY) = unionBox(g)
            let bw = maxX - minX + 1, bh = maxY - minY + 1
            let pad = max(2, Int(Double(max(bw, bh)) * options.padding))
            let ow = bw + pad * 2, oh = bh + pad * 2
            var out = RasterImage(width: ow, height: oh)
            let members = Set(g.map { Int32($0 + 1) })
            var count = 0
            for y in minY...maxY {
                for x in minX...maxX {
                    let p = y * w + x
                    guard members.contains(labels[p]) else { continue }
                    let s = p * 4, d = ((y - minY + pad) * ow + (x - minX + pad)) * 4
                    out.pixels[d] = image.pixels[s]; out.pixels[d + 1] = image.pixels[s + 1]
                    out.pixels[d + 2] = image.pixels[s + 2]; out.pixels[d + 3] = image.pixels[s + 3]
                    count += 1
                }
            }
            pieces.append(Piece(image: out, rect: CGRect(x: minX, y: minY, width: bw, height: bh), pixelCount: count))
        }
        // Læs-rækkefølge: oppefra og ned, venstre mod højre (i rækker)
        let rowHeight = Double(h) * 0.15
        return pieces.sorted {
            let ra = Int(Double($0.rect.midY) / rowHeight), rb = Int(Double($1.rect.midY) / rowHeight)
            return ra == rb ? $0.rect.midX < $1.rect.midX : ra < rb
        }
    }
}
