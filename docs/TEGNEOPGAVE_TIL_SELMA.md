# Tegneopgave til Selma (første omgang)

Det vigtigste er **én krop** - uden den kan der ikke laves figurer. Resten kan komme lidt ad gangen.

## Sådan tegner man, så det virker bedst

- Hvidt papir, **én ting pr. ark** eller flere ting med god luft imellem (mindst 3 fingre).
- Tegn en **tydelig kontur** hele vejen rundt (tusch eller blød blyant). Farv gerne indeni - spillet kan altid farve om.
- Lukkede former er bedst: så kan malerspanden fylde dem. Et bælte, en lomme eller en søm som en streg tværs over giver flere områder at farve.
- Tøj tegnes **hver del for sig**: en trøje for sig, bukser for sig, en sko (så spejlvender spillet den anden), strømper.
- Tegn kroppen **uden tøj** (fx i undertøj), stående med arme lidt ud fra siden og benene let adskilt.
  Hår, øjne og mund tegnes på separate ark - så kan de skiftes.
- Møbler set lige forfra eller lidt fra siden. Huse set forfra.
- Mønstre: et lille firkantet felt fyldt med prikker/striber/hjerter - det bliver "tapet" på alt.

## Ark 1 (i dag) - det der sætter stilen

1. **En krop** (uden tøj)
2. **Et hår**
3. **Øjne** og **en mund** (på samme ark, med luft imellem)
4. **En kjole** OG **en trøje** + **et par bukser**
5. **En sko** og **en strømpe**
6. **En stol** eller **en seng**
7. **Et mønster** (prikker)

## Ark 2 (senere)

Et hus set forfra, et træ, en blomst, en lampe, et bord, et kæledyr, tapet, gulv, en hat, briller, en taske,
og et "knappe-ark": hus, person, kamera, pil, flueben, skraldespand, pensel.

## Lærdom fra ark 1 (13. oktober 2026)

- Ark 1 gav: en krop (pigen), en mund, højre og venstre hånd, og fire kæledyr. Flot.
- **Kun papiret i billedet.** Lagnet omkring papiret blev til "tegning" (folder og skygger), så den
  automatiske opdeling gav én klump. Zoom ind så papiret fylder hele billedet, eller læg det på et bord.
- **Ring + pil = "skal med"** virker fint som aftale, men ringene skal klippes væk bagefter. Det gør
  `Tools/ingest/manual_crop.py` med en lille JSON-fil pr. ark (`Tegninger/indbakke/ark1.json` er eksemplet).
  Nemmere for næste gang: tegn det, der skal med, på ét ark, og det der ikke skal med, på et andet.
- Pigen er tegnet **med tøj på**. Hun er lagt ind som grundfigur, så tøj og hår tegnet senere lægges ovenpå.
  Når Selma tegner en krop i undertøj, bliver det den rigtige basis.
- Der var ingen farver (kuglepen), så paletten er stadig tom. Farveblyanter/tusch næste gang giver spillet sine farver.
- Hun tegnede hænder separat - det er nu en figur-del i spillet (højre og venstre hånd hver for sig).

## Sådan tager man billedet

- Dagslys eller godt loftlys, ingen skarp skygge af telefonen over papiret.
- Lige oppefra, så hele arket er med og fylder det meste af billedet.
- Hellere lidt for langt væk end skævt. Spillet retter selv perspektivet, hvis arket kan ses tydeligt.

## Hvad der sker bagefter

Thomas lægger fotoet i `Tegninger/indbakke/` og kører `ingest.py --review`. Så er tegningerne med i spillet,
og stilen (farver, streg, rundhed) regnes ud af dem. Første gang kigger vi på resultatet sammen og justerer.
