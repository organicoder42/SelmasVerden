# Selmas Spil - noter til Claude Code

- Sprog: al tekst i appen, kommentarer og docs er på dansk. Kode-identifikatorer på engelsk.
- Ingen "egen" stil: UI'et bruger kun `Theme`-tokens (`Core/Style/Theme.swift`). Hårdkod aldrig farver, fonte eller
  ikoner i views; stilen skal komme fra `StyleSeed.json`, som udledes af Selmas tegninger (`docs/STYLE_FROM_SELMA.md`).
- Xcode er muligvis ikke installeret. Typetjek alt mod macOS-SDK'et før du siger noget "virker":
  `xcrun swiftc -typecheck -sdk "$(xcrun --show-sdk-path)" -target arm64-apple-macosx14.0 -swift-version 5 $(find SelmasSpil -name "*.swift")`
  Hold derfor kernen UIKit-fri (CGImage, ikke UIImage); iOS-specifikke modifiers pakkes i `#if os(iOS)`.
- Kernelogik (`Core/`, `Services/Vision/`) kan køres som macOS-executable til hurtige eksperimenter - se harness-mønstret i git-historik/`docs/ARCHITECTURE.md`.
- `project.yml` er sandheden; `SelmasSpil.xcodeproj` genereres med `xcodegen generate` og må gerne regenereres.
- `AssetCategory`-rå-værdier og `ClaudeClassifier.systemPrompt` skal holdes identiske med `Tools/ingest/ingest.py`.
- API-nøgler: aldrig i kode eller git. Appen: nøglering. Mac: `ANTHROPIC_API_KEY` i miljøet.
