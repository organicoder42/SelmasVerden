# Stilen kommer fra Selma

Princip: **vi designer ikke udseendet - vi måler det.** Alt det, et designer normalt vælger (farver, stregtykkelse,
hvor runde hjørnerne er, ikoner, skrift), udledes af hendes tegninger og lægges i `Resources/Style/StyleSeed.json`.
Indtil den første tegning er inde, er spillet neutralt gråt, så intet "fremmed" design sætter sig fast.

## Hvad der måles (Tools/ingest/ingest.py --style)

| Felt | Udledes af | Bruges til |
|---|---|---|
| `palette` | de 8 hyppigste mættede farver på tværs af alle hendes tegninger | knapper, markering, malerspandens første farver |
| `ink` | gennemsnitsfarven af hendes mørke konturstreger | tekst og rammer (sjældent helt sort - ofte mørkegrå/blå/brun) |
| `strokeWeight` | median stregtykkelse (promille af tegningens højde) | tykkelsen på rammer og knapper |
| `roundness` | hvor meget hendes figurer afviger fra firkanter | hjørnerunding på kort og knapper |
| `paper` | papirets tone | baggrund |
| `fontName` | (senere) en font lavet af hendes bogstaver | al tekst |
| `scene` | (endnu ikke udledt - faste startværdier) himmel, asfalt, græs, buske | baggrund på gaden og i haven, indtil der findes tegnede `sky`/`ground`-assets |

## Hvad der tegnes direkte

- **Knapper og ikoner** (`uiIcon`): hus, person, kamera, pil, flueben, skraldespand, pensel, spejl, plus, minus.
  Navngiv ikonet præcis som knappen hedder i spillet ("Leg", "Figurer", "Nye tegninger", "Mine tegninger", "Kamera",
  "Flyt", "Farv", "Tag af", "Spejl", "Større", "Mindre", "Forrest", "Kopi", "Fjern", "Fortryd", "Færdig", "Ting",
  "Gaden", "Nyt hus", "Udseende", "Ny etage", "Ny figur", "Navn", "Start forfra"), så bruges det automatisk.
  Når de findes i biblioteket, bruges de i stedet for systemsymbolerne.
- **Baggrunde**: himmel, jord, tapet, gulv - det er assets, ikke farver.
- **App-ikonet**: hendes tegning.

## Rækkefølge

1. Første tegning i dag (se TEGNEOPGAVE) → `ingest.py` → StyleSeed v1 → hele appen skifter farver/streg.
2. Når der er 10+ tegninger: paletten bliver stabil; vi fryser den som "Selma-palet v1".
3. Ikon-ark: hun tegner knapperne på ét ark; de lægges ind som `uiIcon`.
4. Bogstav-ark (valgfrit): A-Å + tal → font (fx via Calligraphr) → `fontName`.
