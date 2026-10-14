#!/bin/zsh
# Opretter et Python-miljø til ingest-værktøjet (kun første gang).
set -e
cd "$(dirname "$0")"
PY=${PYTHON:-/opt/homebrew/bin/python3.12}
[ -d .venv ] || "$PY" -m venv .venv
.venv/bin/pip install -q --upgrade pip
.venv/bin/pip install -q -r requirements.txt
echo "Klar. Kør:  .venv/bin/python ingest.py --help"
