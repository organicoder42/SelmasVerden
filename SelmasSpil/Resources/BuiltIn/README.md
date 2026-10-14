# Tegninger der følger med spillet

Denne mappe fyldes af `Tools/ingest/ingest.py`, som tager et foto af en tegning, klipper
papiret væk, deler arket op, lader Claude sortere delene i kategorier og skriver PNG-filer
plus `manifest.json` herind. Appen læser mappen ved start (se `AssetLibrary.load()`).

Læg aldrig filer herind i hånden - kør værktøjet, så manifestet passer.
