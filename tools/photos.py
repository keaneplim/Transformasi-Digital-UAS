"""POI and facility photos: fetch → light, fair AI retouch → structure guard → credits.

Sources (decision 2026-11-12): our own survey photos (7 Nov, HEIC originals in
survey/raw/photos/, gitignored) and Wikimedia Commons files with a free licence (CC0, PD,
CC BY, CC BY-SA). No Google Places/Maps photos: their terms forbid storing or redistributing them.

Retouch: Vertex AI `gemini-3-pro-image` with a fixed prompt that allows only exposure, white
balance, shadow/highlight recovery, light noise/haze reduction and gentle sharpening, and blurs
faces (PROGRESS issue #24). It forbids adding, removing or moving anything, rewriting signs,
sky replacement and stylised looks. A structural-similarity guard rejects results whose layout
changed; every result also goes into a before/after contact sheet for human review.

Outputs: assets/images/<file> (≤1600 px JPEG, no metadata), assets/content/image_credits.json,
`images` lists in pois.json / facilities.json (with --apply).

Usage:
  python3 tools/photos.py fetch                  download Commons files + convert survey HEIC
  python3 tools/photos.py enhance [--force]      retouch (Gemini), guard, write assets/images
  python3 tools/photos.py apply                  write image lists + image_credits.json
  python3 tools/photos.py sheet OUT.html         before/after contact sheet
Auth: gcloud ADC (see CLAUDE.local.md). Needs Pillow and macOS `sips`.
"""

from __future__ import annotations

import argparse
import base64
import html
import json
import re
import shutil
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from datetime import date
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CONTENT = ROOT / "assets" / "content"
IMAGES = ROOT / "assets" / "images"
RAW = ROOT / "survey" / "raw"
SURVEY = RAW / "photos"
COMMONS = RAW / "commons"  # gitignored: originals + metadata
WORK = RAW / "photo_work"  # gitignored: source JPEGs + Gemini outputs
CREDITS = CONTENT / "image_credits.json"
UA = {"User-Agent": "jelajah-taman-photos/1.0 (student project; Wikimedia API etiquette)"}

MODEL = "gemini-3-pro-image"
FALLBACK_MODEL = "gemini-3.1-flash-image"
MAX_PX = 1600
GUARD_MIN = 0.50  # structural similarity (0..1) below this → rejected
SURVEY_AUTHOR = "Kelompok 5 Jelajah Taman (survei 7 Nov 2026)"
FREE = re.compile(r"^(CC0|Public domain|PD|CC BY(-SA)? \d\.\d)", re.I)

PROMPT = """You are retouching a real documentary photo for a public park guide app. Make it look \
clean and well exposed, like a careful photographer's edit, while staying truthful to the scene.
Allowed: correct exposure and white balance; recover shadows and highlights; reduce digital noise \
and slight haze; gentle sharpening; straighten a visibly tilted horizon by a degree or two; mild, \
natural contrast.
Not allowed: adding, removing, moving or reshaping any object, plant, building, sign, animal or \
person; changing, retyping or "fixing" any text; replacing, recolouring or dramatising the sky; \
changing season, weather or time of day; HDR, glow, painterly, cinematic or teal-orange looks; \
strong saturation; cropping, zooming or changing the framing.
Privacy: if a human face is visible, blur that face so the person can't be recognised, and \
change nothing else about the person.
Return the full image with the same framing and aspect ratio."""

# (output file, owner id, source kind, source ref) — order inside an owner = gallery order.
PHOTOS: list[tuple[str, str, str, str]] = [
    ("p01_gerbang.jpg", "P01", "survey", "IMG_4276.HEIC"),
    ("p02_monumen.jpg", "P02", "commons", "File:Monumen Patung Taman Hutan Raya Ir. Djuanda - panoramio.jpg"),
    ("p02_monumen_2.jpg", "P02", "commons", "File:Monumen Patung Taman Hutan Raya Ir. Djuanda - panoramio (1).jpg"),
    ("p04_kolam.jpg", "P04", "commons", "File:Tahura Dago - panoramio (10).jpg"),
    ("p04_kolam_2.jpg", "P04", "commons", "File:Danau Tahura Dago - panoramio.jpg"),
    ("p05_gua_jepang.jpg", "P05", "commons", "File:Gua Jepang di Tahura tampak dari depan.jpg"),
    ("p05_tugu.jpg", "P05", "commons", "File:Tugu gua Jepang di Tahura.jpg"),
    ("p06_mulut_gua.jpg", "P06", "survey", "IMG_4238.HEIC"),
    ("p06_goa_belanda.jpg", "P06", "commons", "File:Goa Belanda di Bandung.jpg"),
    ("p06_lorong.jpg", "P06", "survey", "IMG_4241.HEIC"),
    ("p07_rusa.jpg", "P07", "commons", "File:RUSA di TAHURA JUANDA BANDUNG.jpg"),
    ("p07_kandang.jpg", "P07", "commons", "File:Penangkaran Rusa Timor di Tahura.jpg"),
    ("p07_papan.jpg", "P07", "survey", "IMG_4252.HEIC"),
    ("p08_pinus.jpg", "P08", "commons", "File:Tahura Dago - panoramio (5).jpg"),
    ("p10_flora.jpg", "P10", "commons", "File:Tahura Dago - panoramio.jpg"),
    ("p10_pasang.jpg", "P10", "commons", "File:Taman Hutan Raya Ir. Djuanda Dago Bandung - panoramio (6).jpg"),
    ("p11_curug_omas.jpg", "P11", "commons", "File:Air Terjun Curug Omas Maribaya Lembang,10062017.jpg"),
    ("p11_curug_omas_2.jpg", "P11", "commons", "File:Curug Omas Bandung.jpg"),
    ("fs01_toilet.jpg", "FS01", "survey", "IMG_4275.HEIC"),
    ("fs06_toilet.jpg", "FS06", "survey", "IMG_4266.HEIC"),
    ("fs07_musala.jpg", "FS07", "survey", "IMG_4267.HEIC"),
    ("fs08_saung.jpg", "FS08", "survey", "IMG_4262.HEIC"),
    ("fs09_saung.jpg", "FS09", "survey", "IMG_4264.HEIC"),
    ("fs10_gazebo.jpg", "FS10", "survey", "IMG_4274.HEIC"),
]


def slug(title: str) -> str:
    return re.sub(r"[^A-Za-z0-9]+", "_", title.removeprefix("File:")).strip("_")[:80]


def source_jpg(out: str) -> Path:
    return WORK / "src" / out


def enhanced_png(out: str) -> Path:
    return WORK / "enhanced" / (Path(out).stem + ".png")


# ---- fetch --------------------------------------------------------------------------------
def commons_info(titles: list[str]) -> dict:
    q = urllib.parse.urlencode({"action": "query", "prop": "imageinfo", "iiprop": "url|size|extmetadata",
                                "iiurlwidth": 2400, "titles": "|".join(titles), "format": "json"})
    with urllib.request.urlopen(urllib.request.Request("https://commons.wikimedia.org/w/api.php?" + q,
                                                       headers=UA), timeout=60) as r:
        d = json.load(r)
    norm = {n["to"]: n["from"] for n in d["query"].get("normalized", [])}
    out = {}
    for p in d["query"]["pages"].values():
        if "imageinfo" not in p:
            sys.exit(f"Commons: missing {p['title']}")
        ii = p["imageinfo"][0]
        m = ii["extmetadata"]
        strip = lambda k: re.sub(r"<[^>]+>", "", m.get(k, {}).get("value", "")).strip()
        out[norm.get(p["title"], p["title"])] = {
            "url": ii.get("thumburl") or ii["url"], "page": ii["descriptionurl"],
            "author": strip("Artist") or strip("Credit"), "license": strip("LicenseShortName"),
            "license_url": m.get("LicenseUrl", {}).get("value", ""), "width": ii["width"], "height": ii["height"],
        }
    return out


def normalize(path: Path):
    """Apply the EXIF rotation to the pixels and drop all metadata (HEIC → JPEG keeps the flag)."""
    from PIL import Image, ImageOps  # noqa: PLC0415

    im = ImageOps.exif_transpose(Image.open(path)).convert("RGB")
    im.save(path, "JPEG", quality=92)


def fetch():
    (WORK / "src").mkdir(parents=True, exist_ok=True)
    COMMONS.mkdir(parents=True, exist_ok=True)
    meta_path = COMMONS / "meta.json"
    meta = json.loads(meta_path.read_text(encoding="utf-8")) if meta_path.exists() else {}
    titles = [ref for _, _, kind, ref in PHOTOS if kind == "commons"]
    for i in range(0, len(titles), 20):
        meta.update(commons_info(titles[i:i + 20]))
    for out, _, kind, ref in PHOTOS:
        dst = source_jpg(out)
        if kind == "survey":
            subprocess.run(["sips", "-s", "format", "jpeg", "-Z", "2400", str(SURVEY / ref), "--out", str(dst)],
                           check=True, capture_output=True)
            normalize(dst)
            continue
        info = meta[ref]
        if not FREE.match(info["license"]):
            sys.exit(f"{ref}: licence {info['license']!r} is not free — pick another file")
        orig = COMMONS / (slug(ref) + ".jpg")
        if not orig.exists():
            with urllib.request.urlopen(urllib.request.Request(info["url"], headers=UA), timeout=120) as r:
                orig.write_bytes(r.read())
            time.sleep(1)
        subprocess.run(["sips", "-s", "format", "jpeg", "-Z", "2400", str(orig), "--out", str(dst)],
                       check=True, capture_output=True)
        normalize(dst)
    meta_path.write_text(json.dumps(meta, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"fetched {len(PHOTOS)} sources into {WORK.relative_to(ROOT)}/src")


# ---- enhance ------------------------------------------------------------------------------
def gcloud(*args) -> str:
    exe = shutil.which("gcloud") or str(Path.home() / "google-cloud-sdk" / "bin" / "gcloud")
    return subprocess.run([exe, *args], check=True, capture_output=True, text=True).stdout.strip()


def retouch(src: Path, model: str, token: str, project: str) -> bytes:
    body = {"contents": [{"role": "user", "parts": [
        {"inlineData": {"mimeType": "image/jpeg", "data": base64.b64encode(src.read_bytes()).decode()}},
        {"text": PROMPT}]}],
        "generationConfig": {"responseModalities": ["IMAGE"], "temperature": 0.2,
                             **({"imageConfig": {"imageSize": "2K"}} if model == MODEL else {})}}
    url = (f"https://aiplatform.googleapis.com/v1/projects/{project}/locations/global/publishers/google/"
           f"models/{model}:generateContent")
    for attempt in range(4):
        req = urllib.request.Request(url, data=json.dumps(body).encode(), headers={
            "Authorization": f"Bearer {token}", "x-goog-user-project": project, "Content-Type": "application/json"})
        try:
            with urllib.request.urlopen(req, timeout=300) as r:
                d = json.load(r)
            cand = (d.get("candidates") or [{}])[0]
            for part in cand.get("content", {}).get("parts", []):
                if "inlineData" in part:
                    return base64.b64decode(part["inlineData"]["data"])
            if attempt < 3:  # empty answers happen now and then; ask again
                time.sleep(5)
                continue
            raise RuntimeError(f"no image ({cand.get('finishReason')}): {json.dumps(d)[:200]}")
        except urllib.error.HTTPError as e:
            if e.code in (429, 500, 503) and attempt < 3:
                time.sleep(10 * 2 ** attempt)
                continue
            raise RuntimeError(f"HTTP {e.code}: {e.read()[:300]!r}") from e
    raise RuntimeError("unreachable")


def similarity(a_path: Path, b_path: Path) -> tuple[float, float]:
    """(structural similarity of edges 0..1, aspect-ratio difference)."""
    from PIL import Image, ImageFilter, ImageOps  # noqa: PLC0415

    a, b = Image.open(a_path), Image.open(b_path)
    aspect = abs(a.width / a.height - b.width / b.height) / (a.width / a.height)
    size = (160, round(160 * a.height / a.width))

    def prep(im):
        g = ImageOps.grayscale(im.convert("RGB")).resize(size, Image.LANCZOS)
        return list(g.filter(ImageFilter.FIND_EDGES).tobytes()), list(g.tobytes())

    (ea, ga), (eb, gb) = prep(a), prep(b)

    def corr(x, y):
        n = len(x)
        mx, my = sum(x) / n, sum(y) / n
        sxy = sum((p - mx) * (q - my) for p, q in zip(x, y))
        sx = sum((p - mx) ** 2 for p in x) ** 0.5
        sy = sum((q - my) ** 2 for q in y) ** 0.5
        return sxy / (sx * sy) if sx and sy else 0.0

    # luminance layout (robust to exposure changes) and edge layout (catches added/removed things)
    return 0.5 * corr(ga, gb) + 0.5 * corr(ea, eb), aspect


def enhance(force: bool, only: set[str] | None):
    (WORK / "enhanced").mkdir(parents=True, exist_ok=True)
    token, project = gcloud("auth", "application-default", "print-access-token"), gcloud("config", "get-value", "project")
    report = {}
    report_path = WORK / "report.json"
    if report_path.exists():
        report = json.loads(report_path.read_text(encoding="utf-8"))
    for out, owner, kind, ref in PHOTOS:
        if only and out not in only and owner not in only:
            continue
        src, png = source_jpg(out), enhanced_png(out)
        if not src.exists():
            sys.exit(f"{out}: run `fetch` first")
        model = MODEL
        png_new = force or not png.exists()
        if png_new:
            print(f"{out}: retouching with {model} …", flush=True)
            try:
                png.write_bytes(retouch(src, model, token, project))
            except RuntimeError as e:
                print(f"  {model} failed ({e}); trying {FALLBACK_MODEL}")
                model = FALLBACK_MODEL
                try:
                    png.write_bytes(retouch(src, model, token, project))
                except RuntimeError as e2:
                    print(f"  {model} failed too ({e2}); keeping the original")
                    shutil.copy(src, png)
                    model = "none"
        score, aspect = similarity(src, png)
        ok = score >= GUARD_MIN and aspect <= 0.03
        prev = report.get(out, {}).get("model")
        report[out] = {"owner": owner, "model": model if (force or prev is None or png_new) else prev,
                       "similarity": round(score, 3), "aspect_diff": round(aspect, 3), "accepted": ok}
        chosen = png if ok else src
        IMAGES.mkdir(parents=True, exist_ok=True)
        subprocess.run(["sips", "-s", "format", "jpeg", "-s", "formatOptions", "82", "-Z", str(MAX_PX),
                        str(chosen), "--out", str(IMAGES / out)], check=True, capture_output=True)
        strip_metadata(IMAGES / out)
        print(f"  {out}: similarity {score:.2f}, aspect Δ {aspect:.1%} → {'retouched' if ok else 'ORIGINAL (rejected)'}")
    report_path.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")


def strip_metadata(path: Path):
    """Re-encode pixels only (drops EXIF/GPS/ICC text chunks)."""
    from PIL import Image  # noqa: PLC0415

    im = Image.open(path).convert("RGB")
    clean = Image.new("RGB", im.size)
    clean.paste(im)
    clean.save(path, "JPEG", quality=82, optimize=True, progressive=True)


# ---- apply --------------------------------------------------------------------------------
def apply():
    report = json.loads((WORK / "report.json").read_text(encoding="utf-8"))
    meta = json.loads((COMMONS / "meta.json").read_text(encoding="utf-8"))
    credits = {}
    by_owner: dict[str, list[str]] = {}
    for out, owner, kind, ref in PHOTOS:
        r = report.get(out)
        if r is None or not (IMAGES / out).exists():
            sys.exit(f"{out}: run `enhance` first")
        by_owner.setdefault(owner, []).append(out)
        edit = (f"Retouch ringan {r['model']} (eksposur, white balance, wajah diburamkan), "
                f"{date.today().isoformat()}" if r["accepted"] else "Tanpa edit")
        if kind == "survey":
            credits[out] = {"source": "survey", "author": SURVEY_AUTHOR, "license": "Milik tim",
                            "license_url": "", "source_url": f"survey/raw/photos/{ref}", "edit": edit}
        else:
            m = meta[ref]
            credits[out] = {"source": "commons", "author": m["author"], "license": m["license"],
                            "license_url": m["license_url"], "source_url": m["page"], "edit": edit}
    for name, key in (("pois.json", "pois"), ("facilities.json", "facilities")):
        path = CONTENT / name
        data = json.loads(path.read_text(encoding="utf-8"))
        for item in data[key]:
            item["images"] = by_owner.get(item["id"], [])
        path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    CREDITS.write_text(json.dumps({"version": 1, "images": credits}, indent=2, ensure_ascii=False) + "\n",
                       encoding="utf-8")
    used = {out for out, *_ in PHOTOS}
    stale = [p.name for p in IMAGES.glob("*.jpg") if p.name not in used]
    print(f"wrote image lists + {CREDITS.relative_to(ROOT)}; unused files in assets/images: {stale or 'none'}")


# ---- sheet --------------------------------------------------------------------------------
def sheet(out_html: Path):
    report = json.loads((WORK / "report.json").read_text(encoding="utf-8"))
    rows = []
    for out, owner, kind, ref in PHOTOS:
        r = report.get(out, {})
        rows.append(f"""<section><h2>{owner} · {html.escape(out)} <small>{kind}: {html.escape(ref)}</small></h2>
<p class="{'ok' if r.get('accepted') else 'bad'}">similarity {r.get('similarity')} · aspect Δ {r.get('aspect_diff')} ·
{'retouched' if r.get('accepted') else 'original kept'} · {r.get('model', '')}</p>
<div class="pair"><figure><img src="{source_jpg(out).as_uri()}"><figcaption>Sebelum</figcaption></figure>
<figure><img src="{(IMAGES / out).as_uri()}"><figcaption>Sesudah (aset app)</figcaption></figure></div></section>""")
    out_html.write_text(f"""<!doctype html><meta charset="utf-8"><title>Foto POI — sebelum/sesudah</title>
<style>body{{font:14px system-ui;margin:24px;background:#faf7ee;color:#1d2a1f}}section{{margin:0 0 32px}}
.pair{{display:grid;grid-template-columns:1fr 1fr;gap:12px}}img{{width:100%;border-radius:10px}}
h2{{font-size:16px;margin:0 0 4px}}small{{color:#667;font-weight:400}}.ok{{color:#2f7a50}}.bad{{color:#b3432f}}
figure{{margin:0}}figcaption{{color:#667;font-size:12px}}</style>
<h1>Foto POI: sebelum / sesudah retouch</h1>{''.join(rows)}""", encoding="utf-8")
    print(f"wrote {out_html}")


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    sub = ap.add_subparsers(dest="cmd", required=True)
    sub.add_parser("fetch")
    e = sub.add_parser("enhance")
    e.add_argument("--force", action="store_true")
    e.add_argument("--only", nargs="*", help="output files or owner ids")
    sub.add_parser("apply")
    s = sub.add_parser("sheet")
    s.add_argument("out", type=Path)
    a = ap.parse_args(argv)
    if a.cmd == "fetch":
        fetch()
    elif a.cmd == "enhance":
        enhance(a.force, set(a.only) if a.only else None)
    elif a.cmd == "apply":
        apply()
    else:
        sheet(a.out)
    return 0


if __name__ == "__main__":
    sys.exit(main())
