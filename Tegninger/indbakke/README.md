# Indbakke

Læg fotos af Selmas tegninger her (jpg/heic/png). Kør derefter:

    Tools/ingest/.venv/bin/python Tools/ingest/ingest.py Tegninger/indbakke/*.jpg --review

Fotos ignoreres af git (de er store). De behandlede udskæringer havner i `../behandlet/`,
og de færdige assets i `SelmasSpil/Resources/BuiltIn/`.
