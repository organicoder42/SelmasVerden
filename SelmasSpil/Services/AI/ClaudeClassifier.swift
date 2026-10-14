import Foundation

/// Sortering med Claude: får alle udskårne dele fra ét ark i én forespørgsel og svarer med
/// struktureret JSON (kategori, navn, evt. opdeling af hele figurer, ankre på kroppe).
/// Rå HTTP mod Messages API - der er ikke et officielt Swift-SDK.
struct ClaudeClassifier: ClassificationService {
    var config: AIConfig
    var apiKey: String?
    var session: URLSession = .shared

    let displayName = "Claude"

    func classify(pieces: [Data], sheetHint: Data?) async throws -> [PieceClassification] {
        guard !pieces.isEmpty else { return [] }
        if !config.usesProxy, (apiKey ?? "").isEmpty { throw ClassificationError.missingAPIKey }

        var request = URLRequest(url: config.endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 120
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        if !config.usesProxy, let apiKey {
            request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        }
        if config.enableFallbacks {
            request.setValue("server-side-fallback-2026-07-01", forHTTPHeaderField: "anthropic-beta")
        }
        if !config.usesProxy, let ws = config.workspaceID, !ws.isEmpty {
            request.setValue(ws, forHTTPHeaderField: "anthropic-workspace-id")
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body(pieces: pieces, sheetHint: sheetHint))

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw ClassificationError.network(error)
        }
        guard let http = response as? HTTPURLResponse else { throw ClassificationError.badResponse("intet HTTP-svar") }
        guard (200..<300).contains(http.statusCode) else {
            let text = String(data: data, encoding: .utf8) ?? ""
            throw ClassificationError.badResponse("HTTP \(http.statusCode): \(text.prefix(300))")
        }
        return try Self.parse(data, expectedCount: pieces.count)
    }

    // MARK: - Forespørgsel

    private func body(pieces: [Data], sheetHint: Data?) -> [String: Any] {
        var content: [[String: Any]] = []
        if let sheetHint {
            content.append(["type": "text", "text": "Her er hele arket (kun til kontekst, skal ikke klassificeres):"])
            content.append(imageBlock(sheetHint))
        }
        for (i, png) in pieces.enumerated() {
            content.append(["type": "text", "text": "Del nr. \(i):"])
            content.append(imageBlock(png))
        }
        content.append(["type": "text", "text": "Klassificér hver del (nr. 0 til \(pieces.count - 1)) og svar som JSON efter skemaet."])

        var body: [String: Any] = [
            "model": config.model,
            "max_tokens": 4096,
            "system": Self.systemPrompt,
            "messages": [["role": "user", "content": content]],
            "output_config": [
                "effort": "low",
                "format": ["type": "json_schema", "schema": Self.schema],
            ],
        ]
        if config.enableFallbacks {
            body["fallbacks"] = "default"
        }
        return body
    }

    private func imageBlock(_ png: Data) -> [String: Any] {
        ["type": "image", "source": ["type": "base64", "media_type": "image/png", "data": png.base64EncodedString()]]
    }

    static let systemPrompt = """
    You sort a child's drawings for a dress-up-and-decorate game (like Toca Boca World). Each image is one \
    cut-out drawing on a transparent background. Decide what each drawing is so it lands in the right drawer \
    of the game. Categories (use the exact id):
    Character parts: body (a body/figure without clothes, or a base doll), hair, eyes, mouth, nose, ears, eyebrows, beard, \
    handLeft, handRight (a single drawn hand; left/right as seen by the viewer).
    Clothing, always as single garments: top (shirt, sweater, t-shirt), bottom (trousers, shorts, skirt), dress, jacket, \
    shoes, socks, hat, glasses, bag, accessory (jewellery, bows, wings...).
    Furniture and things: furniture (bed, chair, table, sofa, lamp...), decoration (pictures, rugs, vases), plant, toy, food, vehicle, pet.
    House parts: houseFacade (a whole house seen from outside), wall (wallpaper/wall texture), floor, door, window, roof, fence, stairs.
    Outdoor: tree, flower, sky, ground, outdoorItem (swing, slide, pool, sandbox...).
    Other: pattern (a repeating pattern tile such as dots, stripes, hearts meant to be used as a texture), \
    uiIcon (a drawing of a button or symbol), fullCharacter (a complete person/creature drawn in one piece, \
    wearing clothes), unknown.
    Rules: a figure wearing clothes is fullCharacter, and you must propose subparts with boxes for hair, eyes, \
    mouth, top, bottom or dress, shoes, socks when visible, plus a 'body' subpart covering the whole figure. \
    For a body, give anchors (normalized x,y in the image) for: hair (top of head), eyes, nose, mouth, ears, \
    top (chest centre), bottom (hips), dress (torso centre), shoes (feet), socks (ankles), hat (top of head), glasses (eyes), \
    handLeft and handRight (the wrists, as seen by the viewer). \
    Names are short, in Danish, child-friendly, describing colour and type, e.g. "Blå trøje med striber". \
    When unsure between two clothing categories prefer the one the shape suggests; use unknown only if it is truly \
    unrecognisable. confidence is 0 to 1.
    """

    static let schema: [String: Any] = {
        let categoryEnum = AssetCategory.allCases.map(\.rawValue)
        let box: [String: Any] = [
            "type": "object",
            "properties": [
                "x": ["type": "number"], "y": ["type": "number"],
                "width": ["type": "number"], "height": ["type": "number"],
            ],
            "required": ["x", "y", "width", "height"],
            "additionalProperties": false,
        ]
        let point: [String: Any] = [
            "type": "object",
            "properties": ["x": ["type": "number"], "y": ["type": "number"]],
            "required": ["x", "y"],
            "additionalProperties": false,
        ]
        let subpart: [String: Any] = [
            "type": "object",
            "properties": [
                "category": ["type": "string", "enum": categoryEnum],
                "name": ["type": "string"],
                "box": box,
            ],
            "required": ["category", "name", "box"],
            "additionalProperties": false,
        ]
        let anchorProps: [String: Any] = Dictionary(uniqueKeysWithValues:
            ["hair", "eyes", "nose", "mouth", "ears", "top", "bottom", "dress", "shoes", "socks", "hat", "glasses", "handLeft", "handRight"].map { ($0, point) })
        let anchors: [String: Any] = [
            "anyOf": [
                [
                    "type": "object",
                    "properties": anchorProps,
                    "required": Array(anchorProps.keys).sorted(),
                    "additionalProperties": false,
                ],
                ["type": "null"],
            ],
        ]
        let item: [String: Any] = [
            "type": "object",
            "properties": [
                "index": ["type": "integer"],
                "category": ["type": "string", "enum": categoryEnum],
                "name": ["type": "string"],
                "confidence": ["type": "number"],
                "subparts": ["type": "array", "items": subpart],
                "anchors": anchors,
                "notes": ["anyOf": [["type": "string"], ["type": "null"]]],
            ],
            "required": ["index", "category", "name", "confidence", "subparts", "anchors", "notes"],
            "additionalProperties": false,
        ]
        return [
            "type": "object",
            "properties": ["items": ["type": "array", "items": item]],
            "required": ["items"],
            "additionalProperties": false,
        ]
    }()

    // MARK: - Svar

    private struct Envelope: Decodable {
        struct Block: Decodable { let type: String; let text: String? }
        struct StopDetails: Decodable { let category: String?; let explanation: String? }
        let content: [Block]
        let stop_reason: String?
        let stop_details: StopDetails?
    }

    private struct Payload: Decodable {
        let items: [PieceClassification]
    }

    static func parse(_ data: Data, expectedCount: Int) throws -> [PieceClassification] {
        let env: Envelope
        do {
            env = try JSONDecoder().decode(Envelope.self, from: data)
        } catch {
            throw ClassificationError.badResponse("kunne ikke læse svaret")
        }
        if env.stop_reason == "refusal" {
            throw ClassificationError.refused(env.stop_details?.explanation ?? env.stop_details?.category ?? "ukendt grund")
        }
        if env.stop_reason == "max_tokens" {
            throw ClassificationError.badResponse("svaret blev afbrudt (for mange dele på ét ark?)")
        }
        guard let text = env.content.first(where: { $0.type == "text" })?.text, let json = text.data(using: .utf8) else {
            throw ClassificationError.badResponse("intet tekstindhold")
        }
        let payload: Payload
        do {
            payload = try JSONDecoder().decode(Payload.self, from: json)
        } catch {
            throw ClassificationError.badResponse("JSON passede ikke til skemaet: \(error)")
        }
        // Sørg for præcis ét svar pr. del, i rækkefølge; udfyld huller med 'unknown'.
        var byIndex: [Int: PieceClassification] = [:]
        for item in payload.items where item.index >= 0 && item.index < expectedCount {
            byIndex[item.index] = item
        }
        return (0..<expectedCount).map {
            byIndex[$0] ?? PieceClassification(index: $0, category: .unknown, name: "Tegning \($0 + 1)",
                                               confidence: 0, subparts: [], anchors: nil, notes: "Ikke klassificeret")
        }
    }
}
