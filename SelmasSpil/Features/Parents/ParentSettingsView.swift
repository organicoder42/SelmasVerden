import SwiftUI

/// Indstillinger for de voksne: API-nøgle til sorteringen og valg af model/endpoint.
struct ParentSettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    @State private var apiKey: String = KeychainStore.apiKey ?? ""
    @State private var endpoint: String = AIConfig.load().endpoint.absoluteString
    @State private var modelName: String = AIConfig.load().model
    @State private var usesProxy: Bool = AIConfig.load().usesProxy
    @State private var fallbacks: Bool = AIConfig.load().enableFallbacks
    @State private var workspaceID: String = AIConfig.load().workspaceID ?? ""
    @State private var saved = false

    var body: some View {
        ZStack {
            theme.paper.ignoresSafeArea()
            VStack(spacing: 0) {
                TopBar(title: "Indstillinger") { EmptyView() }
                Form {
                    Section("Sortering med AI") {
                        Toggle("Gå via egen server (proxy)", isOn: $usesProxy)
                        if !usesProxy {
                            SecureField("Anthropic API-nøgle", text: $apiKey)
                            TextField("Workspace-id (wrkspc_…, kun hvis nøglen kræver det)", text: $workspaceID)
                            Text("Nøglen gemmes kun i enhedens nøglering. Når spillet udgives, skal den ligge på en server i stedet - se docs/ARCHITECTURE.md.")
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                        TextField("Endpoint", text: $endpoint)
                        TextField("Model", text: $modelName)
                        Toggle("Brug reserve-model hvis hovedmodellen afviser", isOn: $fallbacks)
                    }
                    Section("Bibliotek") {
                        LabeledContent("Tegninger i alt", value: "\(model.library.assets.count)")
                        LabeledContent("Lagt ind på denne iPad", value: "\(model.library.assets.filter { $0.source == .imported }.count)")
                        LabeledContent("Følger med spillet", value: "\(model.library.assets.filter { $0.source == .bundled }.count)")
                    }
                    Section("Stil") {
                        LabeledContent("Stil-kilde", value: model.theme.seed.isNeutral ? "Neutral (afventer Selmas tegninger)" : model.theme.seed.derivedFrom.joined(separator: ", "))
                        HStack {
                            ForEach(model.theme.seed.palette.prefix(8), id: \.hex) { c in
                                Circle().fill(Color(c)).frame(width: 24, height: 24)
                            }
                        }
                    }
                    Section {
                        Button("Gem") {
                            KeychainStore.apiKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
                            var cfg = model.aiConfig
                            cfg.endpoint = URL(string: endpoint) ?? AIConfig.anthropicMessagesURL
                            cfg.model = modelName.trimmingCharacters(in: .whitespaces)
                            cfg.usesProxy = usesProxy
                            cfg.enableFallbacks = fallbacks
                            cfg.workspaceID = workspaceID.trimmingCharacters(in: .whitespaces).isEmpty ? nil : workspaceID.trimmingCharacters(in: .whitespaces)
                            model.aiConfig = cfg
                            saved = true
                        }
                        if saved { Text("Gemt").foregroundStyle(.secondary) }
                    }
                }
                .scrollContentBackground(.hidden)
            }
        }
        .gameScreen()
    }
}
