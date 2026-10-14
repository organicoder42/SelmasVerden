import Foundation

/// Hvordan appen taler med Claude. Under udvikling kaldes API'et direkte med en nøgle gemt i nøgleringen.
/// Når spillet udgives, skal `endpoint` pege på vores egen lille server (proxy), så nøglen aldrig
/// ligger på børnenes iPads - se docs/ARCHITECTURE.md.
struct AIConfig: Codable, Sendable, Equatable {
    var endpoint: URL
    var model: String
    /// Hvis vi går via vores egen proxy, sender vi ikke API-nøgle fra appen.
    var usesProxy: Bool
    /// Tænder serverens egen reserve-model hvis hovedmodellen afviser billedet (fx uklart foto).
    var enableFallbacks: Bool
    /// Kræves hvis API-nøglen ikke er bundet til et workspace (header `anthropic-workspace-id`).
    var workspaceID: String?

    static let anthropicMessagesURL = URL(string: "https://api.anthropic.com/v1/messages")!

    static let `default` = AIConfig(
        endpoint: anthropicMessagesURL,
        model: "claude-opus-5-5",
        usesProxy: false,
        enableFallbacks: true,
        // Thomas' workspace i Claude Console. Ikke hemmeligt; nøglen er det hemmelige.
        workspaceID: "wrkspc_01LeW5dqDKCZb9AWjiVk8h3S"
    )

    private static let defaultsKey = "selmasspil.aiconfig"

    static func load() -> AIConfig {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let cfg = try? JSONDecoder().decode(AIConfig.self, from: data) else { return .default }
        return cfg
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: Self.defaultsKey)
        }
    }
}
