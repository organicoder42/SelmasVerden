import XCTest
@testable import SelmasSpil

/// Kører kernelogikken på syntetiske tegninger - ingen rigtige fotos nødvendige.
final class PaintEngineTests: XCTestCase {

    /// Et firkantet "møbel" med mørk kontur og en lodret streg der deler det i to områder.
    private func makeDrawing() -> RasterImage {
        var img = RasterImage(width: 120, height: 80)
        for y in 0..<80 { for x in 0..<120 {
            let i = img.index(x, y)
            let inside = x >= 10 && x < 110 && y >= 10 && y < 70
            guard inside else { continue }
            let edge = x < 13 || x >= 107 || y < 13 || y >= 67 || abs(x - 60) < 2
            if edge {
                img.pixels[i] = 30; img.pixels[i+1] = 30; img.pixels[i+2] = 30
            } else {
                img.pixels[i] = 240; img.pixels[i+1] = 200; img.pixels[i+2] = 120
            }
            img.pixels[i+3] = 255
        }}
        return img
    }

    func testRegionStopsAtOutline() {
        let img = makeDrawing()
        let mask = PaintEngine.region(in: img, seedX: 30, seedY: 40)
        XCTAssertNotNil(mask)
        XCTAssertEqual(mask![40 * 120 + 30], 1, "seed er med")
        XCTAssertEqual(mask![40 * 120 + 90], 0, "højre side er adskilt af stregen")
        XCTAssertEqual(mask![40 * 120 + 11], 0, "konturen fyldes ikke")
        XCTAssertEqual(mask![5 * 120 + 5], 0, "udenfor tegningen fyldes ikke")
    }

    func testColorFillChangesOnlyRegion() {
        var img = makeDrawing()
        let mask = PaintEngine.region(in: img, seedX: 30, seedY: 40)!
        PaintEngine.fill(&img, mask: mask, color: RGBA(r: 0, g: 0, b: 1))
        let left = img.index(30, 40), right = img.index(90, 40)
        XCTAssertLessThan(img.pixels[left], 60, "venstre er blevet blå (lav rød)")
        XCTAssertEqual(img.pixels[right], 240, "højre er urørt")
    }

    func testRenderIsDeterministicAndUndoable() {
        let base = makeDrawing().cgImage()!
        var paint = PaintState()
        paint.add(RegionFill(seed: CGPoint(x: 0.25, y: 0.5), style: .color(RGBA(r: 1, g: 0, b: 0))))
        let a = PaintEngine.render(base: base, paint: paint) { _ in nil }
        let b = PaintEngine.render(base: base, paint: paint) { _ in nil }
        XCTAssertEqual(ImageIO.pngData(a!), ImageIO.pngData(b!))
        paint.undo()
        XCTAssertTrue(paint.isEmpty)
        XCTAssertTrue(PaintEngine.render(base: base, paint: paint) { _ in nil } === base)
    }

    // MARK: - Udklippede tegninger (gennemsigtig inderside)

    /// En kuglepens-tegning som den kommer fra PaperCutout: mørk kontur, alt andet gennemsigtigt.
    /// `gap` laver et hul i toppen af omridset, så bredt som angivet.
    private func makeOutline(gap: Int = 0) -> RasterImage {
        var img = RasterImage(width: 120, height: 80)
        for y in 0..<80 { for x in 0..<120 {
            let inside = x >= 10 && x < 110 && y >= 10 && y < 70
            let edge = inside && (x < 13 || x >= 107 || y < 13 || y >= 67)
            let inGap = y < 13 && abs(x - 60) * 2 < gap
            guard edge, !inGap else { continue }
            let i = img.index(x, y)
            img.pixels[i] = 20; img.pixels[i+1] = 20; img.pixels[i+2] = 20; img.pixels[i+3] = 255
        }}
        // blød kant indenfor konturen (halvt gennemsigtig streg-pixel)
        for x in 13..<107 where abs(x - 60) * 2 >= gap {
            let i = img.index(x, 13); img.pixels[i] = 10; img.pixels[i+1] = 10; img.pixels[i+2] = 10; img.pixels[i+3] = 128
        }
        return img
    }

    func testTransparentInsideOfClosedOutlineIsFilled() {
        var img = makeOutline()
        let mask = PaintEngine.region(in: img, seedX: 60, seedY: 40)
        XCTAssertNotNil(mask, "gennemsigtig inderside skal kunne fyldes")
        XCTAssertEqual(mask![40 * 120 + 60], PaintEngine.MaskValue.fillBehind)
        XCTAssertEqual(mask![40 * 120 + 11], PaintEngine.MaskValue.outside, "konturen fyldes ikke")
        XCTAssertEqual(mask![5 * 120 + 5], PaintEngine.MaskValue.outside, "udenfor tegningen fyldes ikke")
        XCTAssertEqual(mask![13 * 120 + 60], PaintEngine.MaskValue.fillBehind, "den bløde stregkant får farve bagved")

        PaintEngine.fill(&img, mask: mask!, color: RGBA(r: 0, g: 0, b: 1))
        let mid = img.index(60, 40)
        XCTAssertEqual(img.pixels[mid + 3], 255, "indersiden er blevet opak")
        XCTAssertEqual(img.pixels[mid + 2], 255, "... og blå")
        let soft = img.index(60, 13)
        XCTAssertEqual(img.pixels[soft + 3], 255)
        XCTAssertGreaterThan(img.pixels[soft + 2], 100, "blå bagved den bløde kant")
        XCTAssertLessThan(img.pixels[soft + 2], 200, "men stregen står stadig ovenpå")
        let ink = img.index(11, 40)
        XCTAssertEqual(img.pixels[ink], 20, "konturen er urørt")
        XCTAssertEqual(img.pixels[img.index(5, 5) + 3], 0, "udenfor er stadig gennemsigtigt")
    }

    func testSmallGapInOutlineIsClosed() {
        let img = makeOutline(gap: 3)
        let mask = PaintEngine.region(in: img, seedX: 60, seedY: 40)
        XCTAssertNotNil(mask, "et hul på 3 px lukkes")
        XCTAssertEqual(mask![40 * 120 + 60], PaintEngine.MaskValue.fillBehind)
        XCTAssertEqual(mask![5 * 120 + 60], PaintEngine.MaskValue.outside, "fyldet løber ikke ud gennem hullet")
    }

    func testOpenOutlineIsNotFilled() {
        let img = makeOutline(gap: 30)
        XCTAssertNil(PaintEngine.region(in: img, seedX: 60, seedY: 40), "et stort hul betyder at området er 'udenfor'")
        XCTAssertNil(PaintEngine.region(in: img, seedX: 2, seedY: 2), "tryk udenfor tegningen gør intet")
    }

    func testTapOnInkRecolorsOnlyInk() {
        var img = makeOutline()
        let mask = PaintEngine.region(in: img, seedX: 11, seedY: 40)
        XCTAssertNotNil(mask)
        XCTAssertEqual(mask![40 * 120 + 11], PaintEngine.MaskValue.recolor)
        XCTAssertEqual(mask![40 * 120 + 60], PaintEngine.MaskValue.outside, "indersiden er ikke med")
        PaintEngine.fill(&img, mask: mask!, color: RGBA(r: 1, g: 0, b: 0))
        XCTAssertGreaterThan(img.pixels[img.index(11, 40)], 150, "stregen er blevet rød")
        XCTAssertEqual(img.pixels[img.index(60, 40) + 3], 0, "indersiden er stadig gennemsigtig")
    }

    func testPatternFillUsesTile() {
        var img = makeDrawing()
        var tile = RasterImage(width: 4, height: 4)
        for y in 0..<4 { for x in 0..<4 where (x + y) % 2 == 0 {
            let i = tile.index(x, y); tile.pixels[i] = 0; tile.pixels[i+1] = 255; tile.pixels[i+2] = 0; tile.pixels[i+3] = 255
        }}
        let mask = PaintEngine.region(in: img, seedX: 30, seedY: 40)!
        PaintEngine.fill(&img, mask: mask, pattern: tile, tileHeight: 4, background: RGBA.white)
        var greens = 0, whites = 0
        for x in 20..<40 {
            let i = img.index(x, 40)
            if img.pixels[i+1] > 200 && img.pixels[i] < 50 { greens += 1 }
            if img.pixels[i] > 200 && img.pixels[i+1] > 200 { whites += 1 }
        }
        XCTAssertGreaterThan(greens, 5)
        XCTAssertGreaterThan(whites, 5)
    }
}
