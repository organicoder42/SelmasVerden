#!/usr/bin/env python3
"""
Manuel udskæring til ark hvor den voksne selv peger på hvad der skal med (ringe, pile, kasserede ting).

Bokse angives i en JSON-fil, i promille (0-1000) af det orienterede fotos bredde/højde:
{
  "photo": "Tegninger/indbakke/ark1.jpg",
  "items": [
    {"name": "Pige", "category": "body", "box": [210, 208, 434, 658],
     "erase": [[382, 365, 434, 393]], "anchors": {"hair": [0.5, 0.02], ...}},
    {"name": "Hånd", "category": "handRight", "box": [...], "ring": true}   # ring: fjern omsluttende ring + pile
  ]
}
Alt der rører boksens kant smides væk (ringe og pile udenom), småkorn fjernes, og der trimmes til indholdet.
    python manual_crop.py ark.json --preview DIR     # skriv udskæringer + kontaktark, rør ikke bundlet
    python manual_crop.py ark.json                   # læg ind i Resources/BuiltIn og opdatér StyleSeed
"""
import argparse
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

sys.path.insert(0, str(Path(__file__).resolve().parent))
import ingest  # noqa: E402


def strip_enclosing_ring(rgba: np.ndarray) -> np.ndarray:
    """Til ting med "ring": true i spec'en: tegningen er omsluttet af en ring i boksen. Alle streger der
    rører det ydre tomrum fjernes (ringen, pile og tekst udenfor); tegningen rører kun det indre tomrum og
    overlever. Må ikke bruges på lukkede tegninger uden ring - så forsvinder deres egen kontur."""
    mask = rgba[..., 3] > 40
    H, W = mask.shape
    if H < 8 or W < 8:
        return rgba
    empty = ~mask
    seed = np.zeros_like(empty)
    seed[0, :] = seed[-1, :] = seed[:, 0] = seed[:, -1] = True
    outer = ndimage.binary_propagation(seed & empty, mask=empty)
    cy0, cy1, cx0, cx1 = int(H * 0.4), int(H * 0.6), int(W * 0.4), int(W * 0.6)
    if outer[cy0:cy1, cx0:cx1].any():
        return rgba  # ingen lukket ring - rør ikke
    dt = ndimage.distance_transform_edt(mask)
    stroke = 2 * float(np.median(dt[mask])) if mask.any() else 2.0
    n = max(3, int(stroke * 2.5) + 2)
    near_outer = ndimage.binary_dilation(outer, iterations=n)
    out = rgba.copy()
    out[mask & near_outer] = 0
    return out


def clean_crop(rgba: np.ndarray, border_drop=True, min_pixels=12, pad_frac=0.05, ring=False):
    """Behold hovedtegningen (største komponent) og alt indeni den. Smid ringe (store, tynde ovaler),
    kant-berørende rester (pile, ringstumper) og støj væk. Trim og læg luft omkring."""
    if ring:
        rgba = strip_enclosing_ring(rgba)
    mask = rgba[..., 3] > 40
    labels, n = ndimage.label(mask, structure=np.ones((3, 3)))
    if n == 0:
        return None
    H, W = mask.shape
    counts = np.bincount(labels.ravel(), minlength=n + 1)
    objects = ndimage.find_objects(labels)
    edge = set(np.unique(np.concatenate([labels[0, :], labels[-1, :], labels[:, 0], labels[:, -1]]))) - {0}
    is_ring = np.zeros(n + 1, dtype=bool)
    for i, sl in enumerate(objects, start=1):
        bh, bw = sl[0].stop - sl[0].start, sl[1].stop - sl[1].start
        if bh > 0.6 * H and bw > 0.6 * W:
            # En ring har (næsten) ingen pixels i midten af sin egen boks; en tegning af tynde streger har.
            sub = labels[sl] == i
            cy0, cy1 = int(bh * 0.25), int(bh * 0.75)
            cx0, cx1 = int(bw * 0.25), int(bw * 0.75)
            central = sub[cy0:cy1, cx0:cx1].sum() / max(1, counts[i])
            if central < 0.04:
                is_ring[i] = True
    candidates = [i for i in range(1, n + 1) if not is_ring[i]] or list(range(1, n + 1))
    main = max(candidates, key=lambda i: counts[i])
    keep = np.zeros(n + 1, dtype=bool)
    keep[main] = True
    for i in range(1, n + 1):
        if i == main or is_ring[i] or counts[i] < min_pixels:
            continue
        if border_drop and i in edge:
            continue
        if ring:
            # efter ring-fjernelse er småstumper udenfor hovedtegningen rester af ringen
            sl, msl = objects[i - 1], objects[main - 1]
            inside = sl[0].start >= msl[0].start - 3 and sl[0].stop <= msl[0].stop + 3 and sl[1].start >= msl[1].start - 3 and sl[1].stop <= msl[1].stop + 3
            keep[i] = inside
            continue
        keep[i] = True  # løsdele inde i boksen (øjne, knapper, brudte konturer) hører til tegningen
    survivors = ndimage.binary_dilation(keep[labels], iterations=2)
    out = rgba.copy()
    out[~survivors] = 0
    ys, xs = np.where(out[..., 3] > 0)
    if len(ys) == 0:
        return None
    y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
    out = out[y0:y1, x0:x1]
    pad = max(2, int(max(out.shape[:2]) * pad_frac))
    padded = np.zeros((out.shape[0] + 2 * pad, out.shape[1] + 2 * pad, 4), dtype=np.uint8)
    padded[pad:-pad, pad:-pad] = out
    return padded


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("spec", type=Path)
    ap.add_argument("--preview", type=Path, help="skriv kun udskæringer hertil")
    ap.add_argument("--darkness", type=int, default=50, help="hvor meget mørkere end papiret en streg skal være")
    args = ap.parse_args()
    spec = json.loads(args.spec.read_text())
    photo = Path(spec["photo"])
    rgb = ingest.load_photo(photo, max_side=spec.get("max_side", 2400))
    h, w = rgb.shape[:2]
    rgba = ingest.paper_cutout(rgb, darkness_margin=args.darkness)
    manifest = ingest.load_manifest()
    results = []
    for item in spec["items"]:
        x0, y0, x1, y1 = item["box"]
        X0, Y0, X1, Y1 = int(x0 * w / 1000), int(y0 * h / 1000), int(x1 * w / 1000), int(y1 * h / 1000)
        crop = rgba[Y0:Y1, X0:X1].copy()
        for ex0, ey0, ex1, ey1 in item.get("erase", []):
            crop[max(0, int(ey0 * h / 1000) - Y0):int(ey1 * h / 1000) - Y0, max(0, int(ex0 * w / 1000) - X0):int(ex1 * w / 1000) - X0] = 0
        cleaned = clean_crop(crop, border_drop=item.get("border_drop", True), ring=item.get("ring", False))
        if cleaned is None:
            print(f"!! {item['name']}: intet tilbage")
            continue
        results.append((item, cleaned))
        print(f"{item['name']:14s} {item['category']:10s} {cleaned.shape[1]}x{cleaned.shape[0]}")
        if args.preview:
            args.preview.mkdir(parents=True, exist_ok=True)
            Image.fromarray(cleaned, "RGBA").save(args.preview / f"{item['name']}.png")
    if args.preview:
        # kontaktark på hvid baggrund
        cell = 320
        cols = 4
        rows = (len(results) + cols - 1) // cols
        sheet = Image.new("RGB", (cols * cell, rows * cell), (255, 255, 255))
        for i, (item, img) in enumerate(results):
            im = Image.fromarray(img, "RGBA")
            im.thumbnail((cell - 20, cell - 20))
            bg = Image.new("RGB", im.size, (255, 255, 255))
            bg.paste(im, mask=im.split()[3])
            sheet.paste(bg, ((i % cols) * cell + 10, (i // cols) * cell + 10))
        sheet.save(args.preview / "_kontaktark.png")
        print("kontaktark:", args.preview / "_kontaktark.png")
        return
    for item, img in results:
        anchors = {k: {"x": v[0], "y": v[1]} for k, v in item.get("anchors", {}).items()} or None
        ingest.add_asset(manifest, img, item["name"], item["category"], anchors, item.get("notes"), photo.name)
    ingest.save_manifest(manifest)
    ingest.build_style_seed(manifest)
    print(f"{len(results)} tegninger lagt i bundlet; manifest har nu {len(manifest['assets'])} assets")


if __name__ == "__main__":
    main()
