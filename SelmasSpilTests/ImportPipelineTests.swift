import XCTest
@testable import SelmasSpil

final class ImportPipelineTests: XCTestCase {

    /// Papir med gradient og to tegninger + en støjplet.
    private func makeSheet() -> RasterImage {
        var photo = RasterImage(width: 400, height: 300)
        for y in 0..<300 { for x in 0..<400 {
            let i = photo.index(x, y)
            let base = 235 - (x * 40) / 400
            photo.pixels[i] = UInt8(base); photo.pixels[i+1] = UInt8(base - 3); photo.pixels[i+2] = UInt8(base - 8); photo.pixels[i+3] = 255
        }}
        func dot(_ x: Int, _ y: Int, _ r: UInt8, _ g: UInt8, _ b: UInt8) {
            let i = photo.index(x, y); photo.pixels[i] = r; photo.pixels[i+1] = g; photo.pixels[i+2] = b
        }
        for y in 50..<150 { for x in 50..<150 { dot(x, y, 40, 40, 40) } }        // mørk firkant
        for y in 180..<260 { for x in 250..<350 { dot(x, y, 255, 230, 60) } }    // lys gul (kun mætning adskiller den fra papir)
        dot(10, 290, 0, 0, 0)                                                    // støj
        return photo
    }

    func testCutoutRemovesPaperKeepsDrawing() {
        let cut = PaperCutout.cutout(makeSheet())
        XCTAssertEqual(cut.alpha(5, 5), 0, "papir bliver gennemsigtigt")
        XCTAssertEqual(cut.alpha(395, 295), 0, "mørkere papir i højre side bliver også gennemsigtigt")
        XCTAssertEqual(cut.alpha(100, 100), 255, "mørk tegning beholdes")
        XCTAssertEqual(cut.alpha(300, 220), 255, "lys farvet tegning beholdes pga. mætning")
    }

    func testSplitFindsTwoPiecesAndDropsNoise() {
        let pieces = ComponentSplitter.split(PaperCutout.cutout(makeSheet()))
        XCTAssertEqual(pieces.count, 2)
        XCTAssertEqual(Int(pieces[0].rect.minX), 50, "læse-rækkefølge: øverste først")
    }

    func testClassifierParsesStructuredResponse() throws {
        let json = """
        {"content":[{"type":"text","text":"{\\"items\\":[{\\"index\\":1,\\"category\\":\\"shoes\\",\\"name\\":\\"Røde sko\\",\\"confidence\\":0.9,\\"subparts\\":[],\\"anchors\\":null,\\"notes\\":null}]}"}],"stop_reason":"end_turn"}
        """
        let result = try ClaudeClassifier.parse(Data(json.utf8), expectedCount: 2)
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0].category, .unknown, "manglende index udfyldes")
        XCTAssertEqual(result[1].category, .shoes)
        XCTAssertEqual(result[1].name, "Røde sko")
    }

    func testClassifierSurfacesRefusal() {
        let json = #"{"content":[],"stop_reason":"refusal","stop_details":{"category":"x","explanation":"nej"}}"#
        XCTAssertThrowsError(try ClaudeClassifier.parse(Data(json.utf8), expectedCount: 1))
    }

    /// En hel figur deles op: kroppen beholder hele billedet, hver boks bliver sin egen del med pasform = boksens plads.
    func testSplitFullCharacterKeepsFitAndAnchors() throws {
        var img = RasterImage(width: 100, height: 200)
        for y in 0..<200 { for x in 0..<100 {
            let i = img.index(x, y); img.pixels[i] = 30; img.pixels[i+1] = 30; img.pixels[i+2] = 30; img.pixels[i+3] = 255
        }}
        let cg = try XCTUnwrap(img.cgImage())
        var piece = ImportedPiece(image: cg, rectInSheet: .zero, category: .fullCharacter, name: "Pige", confidence: 0.9, subparts: [
            SubpartSuggestion(category: .body, name: "Krop", box: NormalizedBox(x: 0, y: 0, width: 1, height: 1)),
            SubpartSuggestion(category: .top, name: "Trøje", box: NormalizedBox(x: 0.2, y: 0.3, width: 0.6, height: 0.2)),
        ])
        piece.anchors = nil
        let parts = ImportPipeline.splitFullCharacter(piece)
        XCTAssertEqual(parts.count, 2)
        XCTAssertEqual(parts[0].category, .body)
        XCTAssertEqual(parts[0].image.width, 100, "kroppen beholder hele tegningen")
        XCTAssertEqual(parts[1].category, .top)
        XCTAssertEqual(parts[1].image.width, 60)
        XCTAssertEqual(parts[1].image.height, 40)
        let fit = try XCTUnwrap(parts[1].fit)
        XCTAssertEqual(fit.center.x, 0.5, accuracy: 0.001)
        XCTAssertEqual(fit.center.y, 0.4, accuracy: 0.001)
        XCTAssertEqual(fit.heightRatio, 0.2, accuracy: 0.001)
        XCTAssertEqual(parts[0].anchors?["top"]?.y ?? -1, 0.4, accuracy: 0.001, "kroppen får anker fra boksen")
    }

    func testSaveGameRoundTrip() throws {
        var game = SaveGame()
        var c = GameCharacter(name: "Selma", bodyAssetID: UUID())
        c.wear(UUID(), in: .dress)
        c.wear(UUID(), in: .top) // skal smide kjolen af
        XCTAssertNil(c.worn[.dress])
        game.upsert(c)
        game.upsert(House.starter(name: "Hus"))
        let data = try JSONStore.encoder.encode(game)
        let back = try JSONStore.decoder.decode(SaveGame.self, from: data)
        XCTAssertEqual(back.characters.first?.worn[.top]?.assetID, c.worn[.top]?.assetID)
        XCTAssertEqual(back.houses.first?.rooms.count, 4)
    }
}
