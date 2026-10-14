#!/usr/bin/env python3
"""
Selmas Spil - ingest: fra foto af en tegning til assets i app-bundlet.

    .venv/bin/python ingest.py foto.jpg [foto2.jpg ...]      # klip, del op, sortér, skriv til Resources/BuiltIn
    .venv/bin/python ingest.py --style                        # (gen)skab Resources/Style/StyleSeed.json af alle assets
    .venv/bin/python ingest.py foto.jpg --no-ai               # spring Claude over; alt bliver "unknown" (ret i manifest)
    .venv/bin/python ingest.py foto.jpg --review              # vis hver del og bekræft/ret kategori i terminalen

Samme algoritmer som i appen (PaperCutout, ComponentSplitter) - bare i numpy, så vi kan køre dem på Mac
uden Xcode og lægge resultatet i bundlet, som følger med spillet.
"""
import argparse
import base64
import io
import json
import os
import sys
import uuid
from datetime import datetime, timezone
from pathlib import Path

import numpy as np
from PIL import Image, ImageOps
from scipy import ndimage

ROOT = Path(__file__).resolve().parents[2]
BUILTIN = ROOT / "SelmasSpil" / "Resources" / "BuiltIn"
STYLE = ROOT / "SelmasSpil" / "Resources" / "Style" / "StyleSeed.json"
PROCESSED = ROOT / "Tegninger" / "behandlet"

CATEGORIES = [
    "body", "hair", "eyes", "mouth", "nose", "ears", "eyebrows", "beard", "handLeft", "handRight",
    "top", "bottom", "dress", "jacket", "shoes", "socks", "hat", "glasses", "bag", "accessory",
    "furniture", "decoration", "plant", "toy", "food", "vehicle", "pet",
    "houseFacade", "wall", "floor", "door", "window", "roof", "fence", "stairs",
    "tree", "flower", "sky", "ground", "outdoorItem",
    "pattern", "uiIcon", "fullCharacter", "unknown",
]
DEFAULT_HEIGHT = {
    "furniture": 0.35, "decoration": 0.15, "toy": 0.15, "food": 0.15, "plant": 0.25, "flower": 0.25,
    "pet": 0.2, "vehicle": 0.3, "tree": 0.7, "door": 0.6, "window": 0.3, "stairs": 0.8, "fence": 0.25, "outdoorItem": 0.3,
}
NOT_PAINTABLE = {"pattern", "uiIcon", "sky", "ground", "unknown"}

# Skal være identisk med ClaudeClassifier.systemPrompt i appen.
SYSTEM_PROMPT = """You sort a child's drawings for a dress-up-and-decorate game (like Toca Boca World). Each image is one cut-out drawing on a transparent background. Decide what each drawing is so it lands in the right drawer of the game. Categories (use the exact id):
Character parts: body (a body/figure without clothes, or a base doll), hair, eyes, mouth, nose, ears, eyebrows, beard, handLeft, handRight (a single drawn hand; left/right as seen by the viewer).
Clothing, always as single garments: top (shirt, sweater, t-shirt), bottom (trousers, shorts, skirt), dress, jacket, shoes, socks, hat, glasses, bag, accessory (jewellery, bows, wings...).
Furniture and things: furniture (bed, chair, table, sofa, lamp...), decoration (pictures, rugs, vases), plant, toy, food, vehicle, pet.
House parts: houseFacade (a whole house seen from outside), wall (wallpaper/wall texture), floor, door, window, roof, fence, stairs.
Outdoor: tree, flower, sky, ground, outdoorItem (swing, slide, pool, sandbox...).
Other: pattern (a repeating pattern tile such as dots, stripes, hearts meant to be used as a texture), uiIcon (a drawing of a button or symbol), fullCharacter (a complete person/creature drawn in one piece, wearing clothes), unknown.
Rules: a figure wearing clothes is fullCharacter, and you must propose subparts with boxes for hair, eyes, mouth, top, bottom or dress, shoes, socks when visible, plus a 'body' subpart covering the whole figure. For a body, give anchors (normalized x,y in the image) for: hair (top of head), eyes, nose, mouth, ears, top (chest centre), bottom (hips), dress (torso centre), shoes (feet), socks (ankles), hat (top of head), glasses (eyes), handLeft and handRight (the wrists, as seen by the viewer). Names are short, in Danish, child-friendly, describing colour and type, e.g. "Blå trøje med striber". When unsure between two clothing categories prefer the one the shape suggests; use unknown only if it is truly unrecognisable. confidence is 0 to 1."""

POINT = {"type": "object", "properties": {"x": {"type": "number"}, "y": {"type": "number"}}, "required": ["x", "y"], "additionalProperties": False}
ANCHOR_KEYS = ["hair", "eyes", "nose", "mouth", "ears", "top", "bottom", "dress", "shoes", "socks", "hat", "glasses", "handLeft", "handRight"]
SCHEMA = {
    "type": "object",
    "properties": {"items": {"type": "array", "items": {
        "type": "object",
        "properties": {
            "index": {"type": "integer"},
            "category": {"type": "string", "enum": CATEGORIES},
            "name": {"type": "string"},
            "confidence": {"type": "number"},
            "subparts": {"type": "array", "items": {
                "type": "object",
                "properties": {
                    "category": {"type": "string", "enum": CATEGORIES},
                    "name": {"type": "string"},
                    "box": {"type": "object", "properties": {"x": {"type": "number"}, "y": {"type": "number"}, "width": {"type": "number"}, "height": {"type": "number"}},
                            "required": ["x", "y", "width", "height"], "additionalProperties": False},
                },
                "required": ["category", "name", "box"], "additionalProperties": False}},
            "anchors": {"anyOf": [
                {"type": "object", "properties": {k: POINT for k in ANCHOR_KEYS}, "required": ANCHOR_KEYS, "additionalProperties": False},
                {"type": "null"}]},
            "notes": {"anyOf": [{"type": "string"}, {"type": "null"}]},
        },
        "required": ["index", "category", "name", "confidence", "subparts", "anchors", "notes"],
        "additionalProperties": False}}},
    "required": ["items"], "additionalProperties": False,
}


# ---------------------------------------------------------------- billedbehandling

def load_photo(path: Path, max_side=2000) -> np.ndarray:
    im = ImageOps.exif_transpose(Image.open(path)).convert("RGB")
    im.thumbnail((max_side, max_side), Image.LANCZOS)
    return np.asarray(im).astype(np.int32)


def paper_cutout(rgb: np.ndarray, darkness_margin=28, saturation_margin=38, cell=64, softness=24) -> np.ndarray:
    """RGB (H,W,3) -> RGBA (H,W,4) uint8 med papiret gennemsigtigt. Lokalt papir-estimat pr. felt (90. percentil)."""
    h, w, _ = rgb.shape
    lum = (rgb[..., 0] * 299 + rgb[..., 1] * 587 + rgb[..., 2] * 114) // 1000
    sat = rgb.max(axis=2) - rgb.min(axis=2)
    rows, cols = (h + cell - 1) // cell, (w + cell - 1) // cell
    paper = np.zeros((rows, cols))
    for cy in range(rows):
        for cx in range(cols):
            block = lum[cy * cell:(cy + 1) * cell, cx * cell:(cx + 1) * cell]
            paper[cy, cx] = np.percentile(block, 90)
    paper = ndimage.uniform_filter(paper, size=3, mode="nearest")
    paper_full = np.kron(paper, np.ones((cell, cell)))[:h, :w]
    darkness = paper_full - lum - darkness_margin
    colorful = sat - saturation_margin
    score = np.maximum(darkness, colorful)
    alpha = np.clip(score * 255 / softness, 0, 255)
    alpha[score < 0] = 0
    alpha = alpha.astype(np.uint8)
    # despeckle: kræv mindst 2 synlige naboer
    visible = (alpha > 40).astype(np.uint8)
    neighbours = ndimage.convolve(visible, np.ones((3, 3), dtype=np.uint8), mode="constant") - visible
    alpha[(alpha > 0) & (neighbours < 2)] = 0
    rgba = np.dstack([rgb.astype(np.uint8), alpha])
    return rgba


def split_components(rgba: np.ndarray, min_area_fraction=0.0008, merge_fraction=0.025, padding=0.06, alpha_threshold=40):
    """Returnerer liste af (rgba-udsnit, (x, y, w, h), pixelcount) i læse-rækkefølge."""
    h, w, _ = rgba.shape
    mask = rgba[..., 3] >= alpha_threshold
    labels, n = ndimage.label(mask, structure=np.ones((3, 3)))
    if n == 0:
        return []
    counts = np.bincount(labels.ravel())[1:]
    objects = ndimage.find_objects(labels)
    noise = max(6, int(h * w * min_area_fraction * 0.08))
    groups = [[i] for i in range(n) if counts[i] >= noise]
    margin = int(max(w, h) * merge_fraction)

    def box(g):
        ys = [objects[i][0] for i in g]; xs = [objects[i][1] for i in g]
        return (min(s.start for s in xs), min(s.start for s in ys), max(s.stop for s in xs) - 1, max(s.stop for s in ys) - 1)

    merged = True
    while merged:
        merged = False
        for a in range(len(groups)):
            for b in range(a + 1, len(groups)):
                ba, bb = box(groups[a]), box(groups[b])
                if ba[0] - margin <= bb[2] and bb[0] - margin <= ba[2] and ba[1] - margin <= bb[3] and bb[1] - margin <= ba[3]:
                    groups[a] += groups.pop(b)
                    merged = True
                    break
            if merged:
                break
    min_area = int(h * w * min_area_fraction)
    groups = [g for g in groups if sum(counts[i] for i in g) >= min_area]
    pieces = []
    for g in groups:
        x0, y0, x1, y1 = box(g)
        bw, bh = x1 - x0 + 1, y1 - y0 + 1
        pad = max(2, int(max(bw, bh) * padding))
        members = np.isin(labels[y0:y1 + 1, x0:x1 + 1], [i + 1 for i in g])
        crop = rgba[y0:y1 + 1, x0:x1 + 1].copy()
        crop[~members] = 0
        out = np.zeros((bh + 2 * pad, bw + 2 * pad, 4), dtype=np.uint8)
        out[pad:pad + bh, pad:pad + bw] = crop
        pieces.append((out, (x0, y0, bw, bh), int(members.sum())))
    row_h = h * 0.15
    pieces.sort(key=lambda p: (int((p[1][1] + p[1][3] / 2) / row_h), p[1][0] + p[1][2] / 2))
    return pieces


def to_png_bytes(rgba: np.ndarray, max_side=None) -> bytes:
    im = Image.fromarray(rgba, "RGBA")
    if max_side:
        im.thumbnail((max_side, max_side), Image.LANCZOS)
    buf = io.BytesIO()
    im.save(buf, "PNG", optimize=True)
    return buf.getvalue()


# ---------------------------------------------------------------- sortering med Claude

def api_key_from_keychain() -> str | None:
    """Nøglen ligger i Mac'ens nøglering (security add-generic-password -a selmasspil -s anthropic-api-key -w ...)."""
    return keychain("anthropic-api-key")


def keychain(service: str) -> str | None:
    import subprocess
    try:
        out = subprocess.run(["security", "find-generic-password", "-a", "selmasspil", "-s", service, "-w"],
                             capture_output=True, text=True, check=True)
        return out.stdout.strip() or None
    except (subprocess.CalledProcessError, FileNotFoundError):
        return None


def make_client():
    import anthropic
    # Nøgler der ikke er bundet til et workspace kræver 'anthropic-workspace-id' på hvert kald.
    workspace = os.environ.get("ANTHROPIC_WORKSPACE_ID") or keychain("anthropic-workspace-id")
    headers = {"anthropic-workspace-id": workspace} if workspace else None
    if os.environ.get("ANTHROPIC_API_KEY"):
        return anthropic.Anthropic(default_headers=headers)
    key = api_key_from_keychain()
    if key:
        return anthropic.Anthropic(api_key=key, default_headers=headers)
    return anthropic.Anthropic(default_headers=headers)  # evt. 'ant auth login'-profil


def classify(pieces_png: list[bytes], sheet_png: bytes | None, model: str) -> list[dict]:
    client = make_client()
    content = []
    if sheet_png:
        content.append({"type": "text", "text": "Her er hele arket (kun til kontekst, skal ikke klassificeres):"})
        content.append({"type": "image", "source": {"type": "base64", "media_type": "image/png", "data": base64.b64encode(sheet_png).decode()}})
    for i, png in enumerate(pieces_png):
        content.append({"type": "text", "text": f"Del nr. {i}:"})
        content.append({"type": "image", "source": {"type": "base64", "media_type": "image/png", "data": base64.b64encode(png).decode()}})
    content.append({"type": "text", "text": f"Klassificér hver del (nr. 0 til {len(pieces_png) - 1}) og svar som JSON efter skemaet."})

    response = client.beta.messages.create(
        model=model,
        max_tokens=4096,
        system=SYSTEM_PROMPT,
        messages=[{"role": "user", "content": content}],
        output_config={"effort": "low", "format": {"type": "json_schema", "schema": SCHEMA}},
        betas=["server-side-fallback-2026-07-01"],
        fallbacks="default",
    )
    if response.stop_reason == "refusal":
        details = getattr(response, "stop_details", None)
        raise RuntimeError(f"Claude afviste billedet: {getattr(details, 'explanation', None) or getattr(details, 'category', None)}")
    if response.stop_reason == "max_tokens":
        raise RuntimeError("Svaret blev afbrudt - for mange dele på ét ark? Prøv at dele fotoet op.")
    text = next(b.text for b in response.content if b.type == "text")
    items = json.loads(text)["items"]
    by_index = {it["index"]: it for it in items}
    return [by_index.get(i, {"index": i, "category": "unknown", "name": f"Tegning {i + 1}", "confidence": 0, "subparts": [], "anchors": None, "notes": None})
            for i in range(len(pieces_png))]


# ---------------------------------------------------------------- manifest og stil

def load_manifest() -> dict:
    p = BUILTIN / "manifest.json"
    if p.exists():
        return json.loads(p.read_text())
    return {"version": 1, "assets": []}


def save_manifest(m: dict):
    BUILTIN.mkdir(parents=True, exist_ok=True)
    (BUILTIN / "manifest.json").write_text(json.dumps(m, indent=2, ensure_ascii=False, sort_keys=True) + "\n")


def add_asset(manifest: dict, rgba: np.ndarray, name: str, category: str, anchors, notes, source_photo: str) -> dict:
    asset_id = str(uuid.uuid4()).upper()
    file = f"{category}-{asset_id[:8]}.png"
    (BUILTIN / file).write_bytes(to_png_bytes(rgba, max_side=1024))
    h, w = rgba.shape[:2]
    asset = {
        "id": asset_id,
        "name": name,
        "category": category,
        "imageFile": file,
        "pixelSize": [min(w, 1024 * w / max(w, h)), min(h, 1024 * h / max(w, h))],
        "source": "bundled",
        "createdAt": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "tags": [t for t in [notes, f"foto:{source_photo}"] if t],
        "paintable": category not in NOT_PAINTABLE,
        "artist": "Selma",
    }
    if anchors:
        asset["anchors"] = {k: [v["x"], v["y"]] for k, v in anchors.items()}
    if category in DEFAULT_HEIGHT:
        asset["defaultHeight"] = DEFAULT_HEIGHT[category]
    manifest["assets"].append(asset)
    return asset


def build_style_seed(manifest: dict):
    """Palet, stregfarve, stregtykkelse og rundhed udledt af alle bundlede tegninger."""
    pixels = []
    ink = []
    stroke_px = []      # (stregbredde i px, antal mørke pixels) pr. tegning
    heights = {}        # kategori -> [højde i px]
    corner_fill = []
    names = []
    for a in manifest["assets"]:
        p = BUILTIN / a["imageFile"]
        if not p.exists():
            continue
        names.append(a["name"])
        rgba = np.asarray(Image.open(p).convert("RGBA"))
        alpha = rgba[..., 3] > 128
        if alpha.sum() < 50:
            continue
        heights.setdefault(a["category"], []).append(rgba.shape[0])
        rgb = rgba[..., :3][alpha].astype(np.int32)
        lum = (rgb[:, 0] * 299 + rgb[:, 1] * 587 + rgb[:, 2] * 114) // 1000
        dark = lum < 90
        if dark.any():
            ink.append(rgb[dark].mean(axis=0))
            dark_mask = np.zeros_like(alpha)
            dark_mask[alpha] = dark
            # stregbredde = 2 x median-afstand til kanten for stregens pixels (distance transform)
            dt = ndimage.distance_transform_edt(dark_mask)
            stroke_px.append((2 * float(np.median(dt[dark_mask])), int(dark_mask.sum())))
        sat = rgb.max(axis=1) - rgb.min(axis=1)
        colourful = rgb[(sat > 40) & (lum > 60)]
        if len(colourful):
            pixels.append(colourful[np.random.default_rng(0).choice(len(colourful), min(4000, len(colourful)), replace=False)])
        # rundhed: fyld de lukkede former og se hvor meget af boundingboksens fire hjørner der er dækket.
        # Firkantede ting dækker hjørnerne (rundhed 0), runde ting lader dem stå tomme (rundhed 1).
        filled = ndimage.binary_fill_holes(ndimage.binary_dilation(alpha, iterations=2))
        ys, xs = np.where(filled)
        y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
        box = filled[y0:y1, x0:x1]
        ch, cw = max(1, int(box.shape[0] * 0.15)), max(1, int(box.shape[1] * 0.15))
        corners = [box[:ch, :cw], box[:ch, -cw:], box[-ch:, :cw], box[-ch:, -cw:]]
        corner_fill.append(float(np.mean([c.mean() for c in corners])))
    palette = []
    if pixels:
        allpx = np.concatenate(pixels)
        q = (allpx // 24) * 24 + 12
        keys, counts = np.unique(q, axis=0, return_counts=True)
        for c in keys[np.argsort(-counts)]:
            if all(np.abs(c - np.array(p)).sum() > 90 for p in palette):
                palette.append([int(v) for v in c])
            if len(palette) >= 8:
                break
    # Stregtykkelse i promille af en "reference-højde": kroppen hvis der er en (det er den UI'et skal matche),
    # ellers den største tegning. Pixel-vægtet median, så store tegninger tæller mest.
    stroke_weight = 6.0
    if stroke_px:
        widths = np.array([w for w, _ in stroke_px]); weights = np.array([n for _, n in stroke_px], dtype=float)
        order = np.argsort(widths); cum = np.cumsum(weights[order]); median_px = float(widths[order][np.searchsorted(cum, cum[-1] / 2)])
        ref = max(heights.get("body", [])) if heights.get("body") else max(h for hs in heights.values() for h in hs)
        stroke_weight = median_px / ref * 1000
    def hexc(c):
        return {"r": c[0] / 255, "g": c[1] / 255, "b": c[2] / 255, "a": 1}
    # Scene-farver (himmel, asfalt, græs, buske) udledes ikke af tegningerne endnu - de bevares fra det
    # eksisterende seed, så de ikke forsvinder ved en regenerering. Skal holdes identisk med SceneColors.standard.
    scene = {
        "sky": hexc([191, 227, 247]), "asphalt": hexc([138, 141, 147]),
        "grass": hexc([168, 214, 114]), "bush": hexc([111, 191, 90]),
    }
    if STYLE.exists():
        try:
            scene = json.loads(STYLE.read_text()).get("scene", scene) or scene
        except json.JSONDecodeError:
            pass
    seed = {
        "palette": [hexc(c) for c in palette] or [hexc([232, 230, 225])],
        "paper": hexc([246, 244, 239]),
        "ink": hexc(np.mean(ink, axis=0).astype(int)) if ink else hexc([58, 55, 51]),
        "strokeWeight": round(stroke_weight, 2),
        "roundness": round(float(1 - np.mean(corner_fill)), 2) if corner_fill else 0.5,
        "fontName": None,
        "derivedFrom": names,
        "generatedAt": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "scene": scene,
    }
    STYLE.parent.mkdir(parents=True, exist_ok=True)
    STYLE.write_text(json.dumps(seed, indent=2, ensure_ascii=False) + "\n")
    print(f"StyleSeed skrevet: {len(palette)} farver, streg {seed['strokeWeight']:.1f}‰, rundhed {seed['roundness']:.2f} -> {STYLE}")


# ---------------------------------------------------------------- main

def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("photos", nargs="*", type=Path)
    ap.add_argument("--no-ai", action="store_true", help="spring Claude over")
    ap.add_argument("--review", action="store_true", help="bekræft/ret hver del i terminalen")
    ap.add_argument("--style", action="store_true", help="(gen)skab StyleSeed.json af alle bundlede assets")
    ap.add_argument("--model", default="claude-opus-5-5")
    ap.add_argument("--dry-run", action="store_true", help="skriv kun udskæringer til Tegninger/behandlet, rør ikke bundlet")
    args = ap.parse_args()

    manifest = load_manifest()
    PROCESSED.mkdir(parents=True, exist_ok=True)

    for photo in args.photos:
        print(f"\n== {photo.name}")
        rgb = load_photo(photo)
        rgba = paper_cutout(rgb)
        pieces = split_components(rgba)
        print(f"   {len(pieces)} tegninger fundet")
        if not pieces:
            continue
        stem = photo.stem
        Image.fromarray(rgba, "RGBA").save(PROCESSED / f"{stem}-udskaaret.png")
        for i, (img, rect, n) in enumerate(pieces):
            Image.fromarray(img, "RGBA").save(PROCESSED / f"{stem}-del{i}.png")

        if args.no_ai:
            results = [{"index": i, "category": "unknown", "name": f"Tegning {i + 1}", "confidence": 0, "subparts": [], "anchors": None, "notes": None} for i in range(len(pieces))]
        else:
            try:
                results = classify([to_png_bytes(p[0], 512) for p in pieces], to_png_bytes(rgba, 768), args.model)
            except Exception as e:  # netværk, nøgle, afvisning
                print(f"   Sortering fejlede ({e}); alt sættes til 'unknown'. Ret i manifestet eller kør igen.")
                results = [{"index": i, "category": "unknown", "name": f"Tegning {i + 1}", "confidence": 0, "subparts": [], "anchors": None, "notes": str(e)} for i in range(len(pieces))]

        for (img, rect, n), r in zip(pieces, results):
            cat, name = r["category"], r["name"]
            print(f"   [{r['index']}] {cat:14s} {name!r:40s} ({r['confidence']:.2f}) {r.get('notes') or ''}")
            if args.review:
                ans = input("       enter=ok, eller 'kategori[,navn]' (s=spring over): ").strip()
                if ans == "s":
                    continue
                if ans:
                    parts = [p.strip() for p in ans.split(",", 1)]
                    if parts[0] in CATEGORIES:
                        cat = parts[0]
                    else:
                        print(f"       ukendt kategori {parts[0]!r}; beholder {cat}")
                    if len(parts) > 1:
                        name = parts[1]
            if cat == "unknown" and not args.review:
                print("       -> springes over (unknown). Kør med --review for at vælge kategori.")
                continue
            if args.dry_run:
                continue
            add_asset(manifest, img, name, cat, r.get("anchors"), r.get("notes"), photo.name)
        if not args.dry_run:
            save_manifest(manifest)
            print(f"   manifest: {len(manifest['assets'])} assets i alt")

    if args.style or (args.photos and not args.dry_run):
        build_style_seed(manifest)


if __name__ == "__main__":
    main()
