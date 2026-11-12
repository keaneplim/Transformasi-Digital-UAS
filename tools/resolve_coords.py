"""Resolve real coordinates for every POI and facility (replaces the DUMMY layout).

Each point gets one rule, in this priority order:
  SURVEY_EXIF  GPS from our own survey photo (survey/raw/photo_waypoints.csv, 7 Nov 2026)
  OSM          an OpenStreetMap element (node/way/relation) that names or tags the place
  GMAPS        Google Places API (New) result
  ESTIMATE     no source places it precisely: a reasoned position, always [VERIFIKASI]

Every point is written with `coord_source` and `coord_ref` (what exactly was used) and, where a
second source exists, the distance between the two goes into survey/raw/geo/coords_report.csv.
Never invent a position without the ESTIMATE flag (PRD §8.2).

Network calls are cached in survey/raw/geo/places.json and survey/raw/osm/overpass.json, so a
rerun is deterministic and offline. `--refresh` re-queries Google Places (needs gcloud ADC).

Usage:  python3 tools/resolve_coords.py [--refresh] [--dry-run]
"""

from __future__ import annotations

import argparse
import csv
import json
import math
import shutil
import subprocess
import sys
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CONTENT = ROOT / "assets" / "content"
RAW = ROOT / "survey" / "raw"
GEO = RAW / "geo"
OSM_CACHE = RAW / "osm" / "overpass.json"
PLACES_CACHE = GEO / "places.json"
WAYPOINTS = RAW / "photo_waypoints.csv"
REPORT = GEO / "coords_report.csv"

# Places Text Search is restricted to this rectangle (Dago Pakar → Maribaya).
AREA = {"low": {"latitude": -6.866, "longitude": 107.624}, "high": {"latitude": -6.830, "longitude": 107.662}}

# ---- one rule per point -------------------------------------------------------------------
# primary: ("exif", file) | ("osm", "node/123") | ("places", query) | ("estimate", how)
# check:   optional second source, only for the report (agreement distance)
RULES: dict[str, dict] = {
    "P01": {"primary": ("exif", "IMG_4276.HEIC"), "check": ("places", "Pintu Pos 1 Tahura Djuanda")},
    "P02": {"primary": ("estimate", "plaza"),
            "note": "No source places the bust; photos on Commons have no geotag. Plaza between "
                    "museum and gate, to confirm on site."},
    "P03": {"primary": ("osm", "node/4553213462"), "check": ("places", "BP (UPTD) Tahura Ir.H.Djuanda")},
    "P04": {"primary": ("osm_path", "way/98110034"), "check": ("places", "Pakar Lake"),
            "note": "Lakeside path point nearest the OSM lake. Survey photo IMG_4250 shows Kolam "
                    "Tando Harian PLTA Bengkok, not Kolam Pakar."},
    "P05": {"primary": ("osm", "node/3955116392"), "check": ("places", "Gua Jepang")},
    "P06": {"primary": ("exif", "IMG_4238.HEIC"), "check": ("osm", "node/12180637634")},
    "P07": {"primary": ("exif", "IMG_4252.HEIC"), "check": ("osm", "way/1315972950")},
    "P08": {"primary": ("estimate", "pine"),
            "note": "Pine stands line the path between Gua Jepang and Gua Belanda; the point is the "
                    "path vertex nearest their midpoint."},
    "P09": {"primary": ("osm", "node/12180637296"),
            "note": "Only tourism=picnic_site in the core zone (by the Penangkaran Rusa meadow, ~45 m "
                    "from P07, overlapping radii: D01 handles it). Confirm on site which lawn is meant."},
    "P10": {"primary": ("estimate", "flora"),
            "note": "Commemorative plant collection by the entrance plaza (Commons photo geotag, "
                    "low precision)."},
    "P11": {"primary": ("osm", "node/5655820623"), "check": ("places", "Curug Omas Waterfall")},
    "FS01": {"primary": ("exif", "IMG_4275.HEIC")},
    "FS02": {"primary": ("estimate", "office"),
             "note": "No musala mapped inside the park; placed at the park office (BP UPTD Tahura)."},
    "FS03": {"primary": ("osm", "node/9840550617"), "check": ("places", "Kopi_Tahura")},
    "FS04": {"primary": ("places", "Pintu Pos 2 Tahura Djuanda"), "check": ("osm", "node/4258118513")},
    "FS05": {"primary": ("estimate", "pine_bench"),
             "note": "Bench in the pine stand, a few metres from P08."},
    "FS06": {"primary": ("exif", "IMG_4266.HEIC")},
    "FS07": {"primary": ("exif", "IMG_4267.HEIC")},
    "FS08": {"primary": ("exif", "IMG_4262.HEIC"), "check": ("osm", "node/12180637269")},
    "FS09": {"primary": ("exif", "IMG_4264.HEIC"), "check": ("osm", "node/12180637246")},
    "FS10": {"primary": ("exif", "IMG_4274.HEIC")},
}


def haversine(a: tuple[float, float], b: tuple[float, float]) -> float:
    r = 6371008.8
    p1, p2 = math.radians(a[0]), math.radians(b[0])
    dp, dl = p2 - p1, math.radians(b[1] - a[1])
    h = math.sin(dp / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dl / 2) ** 2
    return 2 * r * math.asin(math.sqrt(h))


# ---- sources --------------------------------------------------------------------------------
def load_exif() -> dict[str, tuple[float, float]]:
    with WAYPOINTS.open(encoding="utf-8") as f:
        return {row["file"]: (float(row["lat"]), float(row["lng"])) for row in csv.DictReader(f)}


class Osm:
    def __init__(self, path: Path):
        data = json.loads(path.read_text(encoding="utf-8"))
        self.by_ref = {f"{e['type']}/{e['id']}": e for e in data["elements"]}
        self.paths = [e for e in data["elements"]
                      if e["type"] == "way" and e.get("tags", {}).get("highway") in
                      {"path", "footway", "steps", "track", "pedestrian", "service"} and "geometry" in e]

    def point(self, ref: str) -> tuple[float, float]:
        e = self.by_ref[ref]
        if e["type"] == "node":
            return e["lat"], e["lon"]
        pts = self._ring(e)
        # area-weighted centroid of the outer ring (fine at this scale)
        a = cx = cy = 0.0
        for (y1, x1), (y2, x2) in zip(pts, pts[1:] + pts[:1]):
            c = x1 * y2 - x2 * y1
            a += c
            cx += (x1 + x2) * c
            cy += (y1 + y2) * c
        if abs(a) < 1e-14:
            return sum(p[0] for p in pts) / len(pts), sum(p[1] for p in pts) / len(pts)
        return cy / (3 * a), cx / (3 * a)

    def _ring(self, e: dict) -> list[tuple[float, float]]:
        if e["type"] == "way":
            return [(g["lat"], g["lon"]) for g in e["geometry"]]
        outer = [m for m in e.get("members", []) if m.get("role") == "outer" and "geometry" in m]
        return [(g["lat"], g["lon"]) for m in outer for g in m["geometry"]]

    def nearest_path_vertex_inside(self, ref: str, anchor=None) -> tuple[float, float]:
        ring = self._ring(self.by_ref[ref])
        c = anchor or self.point(ref)
        best, bd = None, float("inf")
        for w in self.paths:
            for g in w["geometry"]:
                q = (g["lat"], g["lon"])
                if _point_in_ring(q, ring) and (d := haversine(q, c)) < bd:
                    best, bd = q, d
        return best or self.nearest_path_vertex(c)

    def nearest_path_vertex(self, p: tuple[float, float]) -> tuple[float, float]:
        best, bd = p, float("inf")
        for w in self.paths:
            for g in w["geometry"]:
                d = haversine(p, (g["lat"], g["lon"]))
                if d < bd:
                    best, bd = (g["lat"], g["lon"]), d
        return best


def _point_in_ring(p, ring) -> bool:
    y, x = p
    inside = False
    for (y1, x1), (y2, x2) in zip(ring, ring[1:] + ring[:1]):
        if (y1 > y) != (y2 > y) and x < (x2 - x1) * (y - y1) / (y2 - y1 + 1e-15) + x1:
            inside = not inside
    return inside


class Places:
    def __init__(self, refresh: bool):
        self.cache = json.loads(PLACES_CACHE.read_text(encoding="utf-8")) if PLACES_CACHE.exists() else {}
        self.refresh = refresh
        self.dirty = False

    def point(self, query: str) -> tuple[tuple[float, float], str]:
        if self.refresh or query not in self.cache:
            self.cache[query] = self._search(query)
            self.dirty = True
        hit = self.cache[query]
        if not hit:
            sys.exit(f"Places: no result for {query!r}")
        return (hit["lat"], hit["lng"]), f"places:{hit['id']} ({hit['name']})"

    def save(self):
        if self.dirty:
            GEO.mkdir(parents=True, exist_ok=True)
            PLACES_CACHE.write_text(json.dumps(self.cache, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")

    @staticmethod
    def _search(query: str) -> dict | None:
        gcloud = shutil.which("gcloud") or str(Path.home() / "google-cloud-sdk" / "bin" / "gcloud")
        run = lambda *a: subprocess.run([gcloud, *a], check=True, capture_output=True, text=True).stdout.strip()
        token = run("auth", "application-default", "print-access-token")
        project = run("config", "get-value", "project")
        body = json.dumps({"textQuery": query, "maxResultCount": 1,
                           "locationRestriction": {"rectangle": AREA}}).encode()
        req = urllib.request.Request("https://places.googleapis.com/v1/places:searchText", data=body, headers={
            "Authorization": f"Bearer {token}", "x-goog-user-project": project,
            "Content-Type": "application/json",
            "X-Goog-FieldMask": "places.id,places.displayName,places.location"})
        with urllib.request.urlopen(req, timeout=60) as r:
            places = json.load(r).get("places", [])
        if not places:
            return None
        p = places[0]
        return {"id": p["id"], "name": p["displayName"]["text"],
                "lat": p["location"]["latitude"], "lng": p["location"]["longitude"]}


# ---- resolve --------------------------------------------------------------------------------
def resolve(kind: str, arg: str, exif, osm: Osm, places: Places, done: dict) -> tuple[tuple[float, float], str, str]:
    if kind == "exif":
        return exif[arg], "SURVEY_EXIF", arg
    if kind == "osm":
        return osm.point(arg), "OSM", f"osm:{arg}"
    if kind == "osm_path":  # visitor-reachable point: path vertex nearest the feature
        return osm.nearest_path_vertex(osm.point(arg)), "OSM", f"osm:{arg} (nearest path)"
    if kind == "osm_path_in":
        a, b = done["P05"], done["P06"]  # main valley trail: keep the point on it
        mid = ((a[0] + b[0]) / 2, (a[1] + b[1]) / 2)
        return osm.nearest_path_vertex_inside(arg, mid), "OSM", f"osm:{arg} (path inside, main trail)"
    if kind == "places":
        p, ref = places.point(arg)
        return p, "GMAPS", ref
    if kind == "estimate":
        if arg == "plaza":  # between the museum (OSM) and the gate (survey), on a path
            m, g = osm.point("node/4553213462"), exif["IMG_4276.HEIC"]
            return osm.nearest_path_vertex(((m[0] + g[0]) / 2, (m[1] + g[1]) / 2)), "ESTIMATE", "plaza museum–gerbang"
        if arg == "pine":
            a, b = done["P05"], done["P06"]
            return osm.nearest_path_vertex(((a[0] + b[0]) / 2, (a[1] + b[1]) / 2)), "ESTIMATE", "jalur Gua Jepang–Gua Belanda"
        if arg == "pine_bench":
            p = done["P08"]
            return (p[0] + 0.00012, p[1] + 0.00010), "ESTIMATE", "±20 m dari P08"
        if arg == "flora":  # Commons "Tahura Dago - panoramio.jpg" (Pasang tree label) geotag
            return (-6.857952, 107.630361), "ESTIMATE", "commons:File:Tahura Dago - panoramio.jpg (geotag)"
        if arg == "office":
            p, ref = places.point("BP (UPTD) Tahura Ir.H.Djuanda")
            return p, "ESTIMATE", ref
    raise ValueError(f"unknown rule {kind}:{arg}")


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--refresh", action="store_true", help="re-query Google Places")
    ap.add_argument("--dry-run", action="store_true", help="print, don't write")
    args = ap.parse_args(argv)

    exif, osm, places = load_exif(), Osm(OSM_CACHE), Places(args.refresh)
    pois_f = json.loads((CONTENT / "pois.json").read_text(encoding="utf-8"))
    fac_f = json.loads((CONTENT / "facilities.json").read_text(encoding="utf-8"))
    items = {i["id"]: i for i in pois_f["pois"] + fac_f["facilities"]}

    done: dict[str, tuple[float, float]] = {}
    rows = []
    for pid, rule in RULES.items():
        (lat, lng), source, ref = resolve(*rule["primary"], exif, osm, places, done)
        lat, lng = round(lat, 6), round(lng, 6)
        done[pid] = (lat, lng)
        check_ref, check_d = "", ""
        if "check" in rule:
            cp, _, cref = resolve(*rule["check"], exif, osm, places, done)
            check_ref, check_d = cref, f"{haversine((lat, lng), cp):.0f}"
        item = items[pid]
        old = (item["lat"], item["lng"])
        item.update({"lat": lat, "lng": lng, "coord_source": source, "coord_ref": ref})
        if source == "ESTIMATE":
            item["coord_note"] = "[VERIFIKASI] " + rule.get("note", "")
        else:
            item.pop("coord_note", None)
        rows.append([pid, item["name"], lat, lng, source, ref, check_ref, check_d,
                     f"{haversine(old, (lat, lng)):.0f}", rule.get("note", "")])
        print(f"{pid:5} {source:12} {lat:.6f},{lng:.6f}  check {check_d or '-':>4} m  {ref}")

    missing = set(items) - set(RULES)
    if missing:
        sys.exit(f"no rule for {sorted(missing)}")
    places.save()
    if args.dry_run:
        return 0
    for name, data in (("pois.json", pois_f), ("facilities.json", fac_f)):
        (CONTENT / name).write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    GEO.mkdir(parents=True, exist_ok=True)
    with REPORT.open("w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(["id", "name", "lat", "lng", "source", "ref", "check_ref", "check_dist_m",
                    "moved_since_last_run_m", "note"])
        w.writerows(rows)
    print(f"wrote pois.json, facilities.json, {REPORT.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
