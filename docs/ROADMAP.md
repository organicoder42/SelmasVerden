# Køreplan

## Nu (uge 1)
- [x] Installér Xcode og byg til iOS: bygger rent med Xcode 27 (13. okt. 2026). Fundet og rettet: `INFOPLIST_KEY_*` blev ignoreret pga. egen Info.plist - alle plist-nøgler ligger nu i `project.yml` under `info`.
- [ ] Kør på rigtig iPad.
- [x] Første tegneark fra Selma → `manual_crop.py` → 8 assets + StyleSeed v1 (13. okt. 2026). Mangler: farver (kuglepen), rigtig krop uden tøj, hår/tøj som dele.
- [ ] Prøv kamera-importen på iPad med rigtige fotos; justér `PaperCutout`-parametre efter hendes papir/tusch.
- [ ] Kør XCTest (`⌘U`).

## Snart
- [ ] Automatisk ark-detektion i `ingest.py` (find papiret, skær resten fra) som i appens `PaperDetector`, så lagen/bordet ikke kommer med.
- [x] Claude-sorteringen testet live på ark 1: 7 af 8 rigtige, pigen blev "hel figur" med 7 forslag til dele (13. okt. 2026).
- [x] Figur-"Flyt": bruger nu figurens faktiske størrelse på skærmen (13. okt. 2026).
- [ ] Spejlvend sko automatisk (venstre/højre) og lad "par" tegnes som én.
- [x] Håndtegnede UI-ikoner (`uiIcon`) bruges automatisk i `BigButton`/`RoundIconButton`, når et ikon har samme navn som knappen (13. okt. 2026).
- [x] Hel-figur-opdeling: `SubpartEditorSheet` viser boksene oven på tegningen; de kan trækkes, skaleres, omdøbes og tilføjes før "Del op". Dele skåret ud af en figur får nu deres `fit`, så de sidder samme sted (13. okt. 2026).
- [ ] Automatisk pasform: AI'en foreslår `fit` for tøj ud fra kroppens ankre (sender kroppen med som kontekst).
- [ ] Lyd: små lyde ved træk/slip/maling (kan også være Selmas egne lyde optaget på iPad).
- [x] Små animationer: ting hopper på plads når de sættes ind, og vrikker når man trykker (13. okt. 2026).

## Før udgivelse
- [ ] Proxy-server til Claude-kald (nøgle væk fra enheden), rate limiting, ingen lagring af fotos.
- [ ] App-ikon og launch screen fra Selmas tegninger.
- [ ] Privatlivs-erklæring, App Store-tekster (dansk + engelsk), skærmbilleder.
- [ ] Ydelse: scener med 50+ ting; evt. flyt scenen til SpriteKit hvis SwiftUI ikke holder 60 fps.
- [ ] iCloud-backup af Documents er med automatisk; overvej eksplicit eksport/import af hele verdenen (zip).
- [ ] Tilgængelighed: VoiceOver-labels på alle knapper (de fleste har), Dynamic Type i tekster.

## Senere / idéer
- "Tegn direkte i spillet" med Apple Pencil som alternativ til papir.
- Flere børn: profiler med hvert sit bibliotek.
- Dele en figur som billede/PDF ("print og klip").
- Lad figurer gå rundt selv (simpel idle-animation, ingen rigging nødvendig - gyng/hop).
