# Arkitektur

SwiftUI-app, iOS 17+, iPad i landskab (iPhone understøttes, men er sekundær). Ingen tredjeparts-pakker.
Kernen er UIKit-fri (CoreGraphics/CoreImage/Vision), så den typetjekker og kan køres på macOS uden Xcode.

```
SelmasSpil/
  App/            SelmasSpilApp, RootView (NavigationStack + Route), AppModel (den ene sandhed)
  Core/
    Models/       AssetCategory (taksonomi), DrawingAsset, PaintState, GameCharacter, House/Room/Placement, SaveGame
    Storage/      FileLocations, JSONStore, ImageIO (PNG/JPEG uden UIKit), AssetLibrary, SaveStore
    Style/        StyleSeed (udledt af tegninger) + Theme (SwiftUI-tokens)
    Rendering/    RasterImage, PaintEngine (flood fill + farve/mønster), AssetRenderer (cache)
  Services/
    Vision/       PaperCutout (papir væk), ComponentSplitter (ark → dele), PaperDetector (perspektiv, Vision)
    AI/           ClassificationService (protokol), ClaudeClassifier (HTTP), HeuristicClassifier, AIConfig, KeychainStore
  Features/       Home, World, Houses, Characters, Paint, Import, Parents  (kun views)
  Resources/      Assets.xcassets, BuiltIn/ (Selmas tegninger + manifest.json), Style/StyleSeed.json
Tools/ingest/     Python: samme pipeline på Mac → skriver ind i Resources/BuiltIn
                  manual_crop.py: ark med håndsatte bokse (ringe/pile/kasserede ting), spec i Tegninger/indbakke/*.json
```

## Datamodel

- **DrawingAsset**: metadata for én PNG med alpha. `category` afgør hvilken skuffe den ligger i, om den kan
  bæres (`wearableSlot`), stilles ind (`isPlaceable`) og farves. `fit` (for tøj) og `anchors` (for kroppe)
  er normaliserede koordinater, så alt skalerer.
- **PaintState**: en liste af `RegionFill` (tryk-punkt + farve/mønster). Vi gemmer handlingerne, ikke billedet.
  Det gør fortryd gratis og filerne små. `AssetRenderer` afspiller dem og cacher resultatet.
- **GameCharacter**: krop + `[WearableSlot: WornItem]`. `WearableSlot.zIndex` er tegne-rækkefølgen.
  `Rig` giver standard-placering; kroppens egne ankre (fra AI'en) overstyrer; barnets "Flyt" overstyrer alt.
- **House → Room → Placement**: rum har `kind` (indoor/garden/roofTerrace/balcony/street) og `level`.
  Placement er en ting eller en figur med normaliseret position/højde.
- **SaveGame**: alt i én JSON i Documents, gemt med 600 ms debounce.

## Import-kæden (foto → assets)

1. `ImageIO.loadOrientedCGImage` - EXIF-orientering bages ind.
2. `PaperDetector.straightened` - Vision finder arket, Core Image retter perspektivet. Springes over hvis ikke fundet.
3. `PaperCutout.cutout` - lokalt papir-estimat (90. percentil pr. 64 px-felt, glattet), så ujævnt lys og
   skygger ikke ødelægger. En pixel beholdes hvis den er mørkere end papiret ELLER mættet (lyse farver som gul).
   Blød kant + despeckle.
4. `ComponentSplitter.split` - 8-forbundne komponenter; småstumper (prikker, øjne) slås sammen med naboer inden
   støjfilter; udskæring kun af gruppens egne pixels; læse-rækkefølge.
5. `ClassificationService.classify` - alle dele fra ét ark i én forespørgsel.
6. `ImportReviewView` - den voksne retter, og `AppModel.commit` skriver PNG + manifest.
   En "hel figur" åbnes i `SubpartEditorSheet`: boksene fra sorteringen ligger oven på tegningen og kan trækkes,
   skaleres (hjørnet), omdøbes, tilføjes og fjernes. "Del op" (`ImportPipeline.splitFullCharacter`) beholder hele
   tegningen som krop, skærer hver boks ud som sin egen del og giver den et `fit` = boksens placering, så delen
   sidder samme sted på figuren i spillet.

Råfotoet gemmes i Documents/Fotos, så alt kan køres igennem igen med bedre algoritmer senere.

### Manuel udskæring (manual_crop.py)

Når et ark er "redigeret" med ringe og pile, eller indeholder ting der ikke skal med, beskrives det i en JSON med
bokse i promille af fotoet. Oprydning pr. boks: største komponent beholdes altid; løsdele i boksen (øjne, brudte
konturer) beholdes; alt der rører boksens kant smides væk (ringstumper, pile); `erase`-bokse fjerner fx
overstregede hænder; `ring: true` fjerner en omsluttende ring ved at slette alle streger der rører det ydre
tomrum. Kroppens `anchors` sættes i samme fil og tjekkes visuelt (overlay) før de lægges ind.

## AI-sortering

`ClaudeClassifier` kalder Messages API direkte (`POST /v1/messages`, `anthropic-version: 2023-06-01`) med
billederne som base64 og **struktureret output** (`output_config.format` med JSON-skema), så svaret altid kan
parses. Model: `claude-opus-5-5`, `effort: low` (klassificering er simpel). `fallbacks: "default"` med beta-header
`server-side-fallback-2026-07-01` er slået til, så en afvisning rutes til en reservemodel; `stop_reason == "refusal"`
håndteres alligevel. Uden net/nøgle bruges `HeuristicClassifier` og alt havner i oversigten til manuel sortering.

**Før udgivelse**: API-nøglen må ikke ligge på børnenes iPads. `AIConfig.usesProxy` + `endpoint` peger på en lille
server (fx Cloudflare Worker/Vercel) der holder nøglen, rate-limiter pr. enhed og videresender samme JSON.
Appen sender da ingen `x-api-key`. Proxyen er ikke skrevet endnu (ROADMAP).

## Stil

Se `STYLE_FROM_SELMA.md`. Teknisk: `Theme` læser `StyleSeed.json` (bundle). Alle views bruger `@Environment(\.theme)`.
Håndtegnede knapper er assets af kategori `uiIcon`. `BigButton` og `RoundIconButton` slår automatisk op i
`AssetLibrary.uiIcon(named:)` med knappens titel/label ("Leg", "Flyt", "Farv" ...): findes der et ikon med samme navn
(uanset store/små bogstaver), vises det i stedet for systemsymbolet. Så Selma tegner knappen, forælderen navngiver den
som knappen hedder, og den dukker op af sig selv.

## Test og verifikation uden Xcode

```sh
xcrun swiftc -typecheck -sdk "$(xcrun --show-sdk-path)" -target arm64-apple-macosx14.0 -swift-version 5 $(find SelmasSpil -name "*.swift")
```
Kernen kan også linkes til en macOS-executable sammen med en `main.swift`, der tegner et syntetisk ark og
skriver PNG'er ud - det var sådan udskæring/opdeling/maling blev verificeret. XCTest-filerne i `SelmasSpilTests/`
kører i Xcode (`⌘U`).

## Udgivelse (forberedt)

- Bundle-id `dk.saabynoer.selmasspil`, automatisk signering, landskab, iPad+iPhone, dansk som udviklingssprog.
- Ingen tracking, ingen konti, ingen eksterne SDK'er → simpel privatlivs-erklæring ("Kids"-kategori kræver
  at AI-kaldet går via vores proxy og at fotos ikke gemmes på server).
- App-ikon: skal være en af Selmas tegninger (1024×1024 i `Assets.xcassets/AppIcon.appiconset`).
