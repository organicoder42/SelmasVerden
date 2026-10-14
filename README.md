# Selmas Spil

Et Toca Boca-agtigt lege-univers til iPad, hvor **alt er tegnet af Selma**: figurer, hår, tøj (hver del for sig),
møbler, mønstre, huse, haver og tagterrasser. Man fotograferer en tegning, spillet klipper den ud af papiret,
deler arket op i de enkelte tegninger og lader Claude sortere dem i de rigtige skuffer.

## Status (13. oktober 2026)

- Hele appen er skrevet (SwiftUI, iOS 17+, iPad-først) og typetjekker. Den er **ikke** bygget eller kørt
  endnu, fordi Xcode ikke er installeret på denne Mac. Næste skridt: installér Xcode, åbn `SelmasSpil.xcodeproj`, kør på iPad.
- Udskæring, opdeling og malerspand er testet på syntetiske "fotos" (se `SelmasSpilTests/`).
- Stilen er bevidst neutral grå. Den udledes af Selmas første tegninger - se `docs/STYLE_FROM_SELMA.md`.
- Selmas første ark er lagt ind (krop, mund, to hænder, fire kæledyr) og StyleSeed v1 er regnet ud af det. Næste tegneopgave: `docs/TEGNEOPGAVE_TIL_SELMA.md`.

## Kom i gang

```sh
# 1) Xcode-projektet genereres fra project.yml (kræver xcodegen: brew install xcodegen)
xcodegen generate
open SelmasSpil.xcodeproj

# 2) Mac-værktøjet der lægger Selmas tegninger ind i spillet
Tools/ingest/setup.sh
# API-nøglen ligger i nøgleringen (security add-generic-password -a selmasspil -s anthropic-api-key -w NØGLE -U)
Tools/ingest/.venv/bin/python Tools/ingest/ingest.py Tegninger/indbakke/kjole.jpg --review
```

Læs videre i `docs/`:

| Fil | Indhold |
|---|---|
| `docs/GAME_DESIGN.md` | Hvad spillet er, skærme, regler |
| `docs/ARCHITECTURE.md` | Kode-struktur, datamodel, import-kæde, AI, udgivelse |
| `docs/STYLE_FROM_SELMA.md` | Hvordan stilen laves af hendes tegninger |
| `docs/TEGNEOPGAVE_TIL_SELMA.md` | Hvad Selma skal tegne først, og hvordan man tager billedet |
| `docs/ROADMAP.md` | Hvad der mangler før det er "et rigtigt spil" |
