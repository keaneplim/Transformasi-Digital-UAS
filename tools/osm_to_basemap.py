"""Build the bundled offline basemap (A01) from OpenStreetMap data + a terrain model.

Outputs (read by lib/modules/map):
  assets/map/basemap.json   vector layers: landcover, water, waterways, roads, paths, buildings,
                            Tahura boundary, 10 m contours, labels. Coordinates are flat
                            [lat, lng, lat, lng, …] arrays.
  assets/map/hillshade.png  soft relief shading, georeferenced by `hillshade.bounds` in the JSON.

Sources (attribution shown in the app):
  - © OpenStreetMap contributors, ODbL — survey/raw/osm/overpass.json (Overpass API, cached)
  - Terrain: Google Elevation API on a 20 m grid — survey/raw/osm/dem_google.json (needs
    GOOGLE_ELEVATION_API_KEY from .env.local, see CLAUDE.local.md). Fallback without a key:
    AWS Terrain Tiles / Mapzen "terrarium" (SRTM, public) — survey/raw/osm/dem_z14.json

`--refresh` re-downloads both (network); without it the build is offline and deterministic.
Needs Pillow for the hillshade (pip3 install pillow).

Usage:  python3 tools/osm_to_basemap.py [--refresh]
"""

from __future__ import annotations

import argparse
import io
import json
import math
import sys
import urllib.parse
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OSM_DIR = ROOT / "survey" / "raw" / "osm"
OSM_CACHE = OSM_DIR / "overpass.json"
DEM_CACHE = OSM_DIR / "dem_z14.json"
GDEM_CACHE = OSM_DIR / "dem_google.json"
GDEM_STEP_M = 20.0
OUT_DIR = ROOT / "assets" / "map"
UA = {"User-Agent": "jelajah-taman-basemap/1.0 (student project)"}

# Map extent: Dago Pakar gate → Curug Omas, with margin. (south, west, north, east)
BOUNDS = (-6.8665, 107.6235, -6.8295, 107.6635)
FETCH_BOUNDS = (-6.868, 107.622, -6.828, 107.664)
DEM_ZOOM = 14
CONTOUR_STEP = 10
BUILDING_BUFFER_M = 400
INDEX_STEP = 50

OVERPASS_QUERY = """[out:json][timeout:170][bbox:{s},{w},{n},{e}];
(way[highway];way[landuse];way[natural];relation[natural];relation[landuse];way[waterway];
way[building];way[leisure];way[amenity];way[tourism];relation[boundary=protected_area];
node[tourism];node[historic];node[natural];node[amenity];node[leisure];node[name];);out geom;"""

LANDCOVER = {
    ("landuse", "forest"): "forest", ("natural", "wood"): "forest",
    ("natural", "scrub"): "scrub",
    ("landuse", "meadow"): "grass", ("natural", "grassland"): "grass", ("landuse", "grass"): "grass",
    ("landuse", "recreation_ground"): "grass", ("leisure", "golf_course"): "grass",
    ("landuse", "farmland"): "farmland", ("landuse", "orchard"): "farmland",
    ("landuse", "residential"): "residential", ("landuse", "commercial"): "residential",
    ("landuse", "cemetery"): "cemetery",
}
ROADS = {"primary", "secondary", "tertiary", "unclassified", "residential", "living_street", "service", "track"}
PATHS = {"path", "footway", "steps", "pedestrian", "cycleway", "bridleway"}
WATERWAYS = {"river", "stream", "canal", "drain", "ditch"}


# ---- geometry helpers ---------------------------------------------------------------------
def m_per_deg(lat: float) -> tuple[float, float]:
    return 111320.0, 111320.0 * math.cos(math.radians(lat))


MY, MX = m_per_deg((BOUNDS[0] + BOUNDS[2]) / 2)


def simplify(pts: list[tuple[float, float]], tol_m: float) -> list[tuple[float, float]]:
    """Douglas–Peucker on (lat, lng) with a metric tolerance."""
    if len(pts) < 3:
        return pts

    def perp(p, a, b):
        ax, ay = (a[1]) * MX, (a[0]) * MY
        bx, by = (b[1]) * MX, (b[0]) * MY
        px, py = (p[1]) * MX, (p[0]) * MY
        dx, dy = bx - ax, by - ay
        if dx == dy == 0:
            return math.hypot(px - ax, py - ay)
        t = max(0, min(1, ((px - ax) * dx + (py - ay) * dy) / (dx * dx + dy * dy)))
        return math.hypot(px - ax - t * dx, py - ay - t * dy)

    keep = [False] * len(pts)
    keep[0] = keep[-1] = True
    stack = [(0, len(pts) - 1)]
    while stack:
        i, j = stack.pop()
        best, idx = 0.0, -1
        for k in range(i + 1, j):
            d = perp(pts[k], pts[i], pts[j])
            if d > best:
                best, idx = d, k
        if best > tol_m and idx > 0:
            keep[idx] = True
            stack += [(i, idx), (idx, j)]
    return [p for p, k in zip(pts, keep) if k]


def chaikin(pts, rounds=1, closed=False):
    for _ in range(rounds):
        if len(pts) < 3:
            return pts
        out = [] if closed else [pts[0]]
        rng = range(len(pts)) if closed else range(len(pts) - 1)
        for i in rng:
            a, b = pts[i], pts[(i + 1) % len(pts)]
            out.append((0.75 * a[0] + 0.25 * b[0], 0.75 * a[1] + 0.25 * b[1]))
            out.append((0.25 * a[0] + 0.75 * b[0], 0.25 * a[1] + 0.75 * b[1]))
        if not closed:
            out.append(pts[-1])
        pts = out
    return pts


def intersects(pts, b=BOUNDS) -> bool:
    lats = [p[0] for p in pts]
    lngs = [p[1] for p in pts]
    return not (max(lats) < b[0] or min(lats) > b[2] or max(lngs) < b[1] or min(lngs) > b[3])


def flat(pts, nd=6) -> list[float]:
    out = []
    for la, ln in pts:
        out += [round(la, nd), round(ln, nd)]
    return out


def ring_area(pts) -> float:
    a = 0.0
    for (y1, x1), (y2, x2) in zip(pts, pts[1:] + pts[:1]):
        a += (x1 * MX) * (y2 * MY) - (x2 * MX) * (y1 * MY)
    return abs(a) / 2


def join_rings(ways: list[list[tuple[float, float]]]) -> list[list[tuple[float, float]]]:
    """Stitch multipolygon member ways into closed rings."""
    segs = [w[:] for w in ways if len(w) >= 2]
    rings = []
    while segs:
        cur = segs.pop(0)
        changed = True
        while cur[0] != cur[-1] and changed:
            changed = False
            for i, s in enumerate(segs):
                if s[0] == cur[-1]:
                    cur += s[1:]
                elif s[-1] == cur[-1]:
                    cur += s[::-1][1:]
                elif s[-1] == cur[0]:
                    cur = s + cur[1:]
                elif s[0] == cur[0]:
                    cur = s[::-1] + cur[1:]
                else:
                    continue
                segs.pop(i)
                changed = True
                break
        if len(cur) >= 4:
            rings.append(cur)
    return rings


def geom(e) -> list[tuple[float, float]]:
    return [(g["lat"], g["lon"]) for g in e.get("geometry", []) if g]


def polygons(e) -> list[tuple[list, list[list]]]:
    """(outer ring, holes) for a closed way or a multipolygon relation."""
    if e["type"] == "way":
        g = geom(e)
        return [(g, [])] if len(g) >= 4 and g[0] == g[-1] else []
    outers = join_rings([geom(m) for m in e.get("members", []) if m.get("role") == "outer"])
    inners = join_rings([geom(m) for m in e.get("members", []) if m.get("role") == "inner"])
    out = []
    for o in outers:
        holes = [i for i in inners if point_in_ring(i[0], o)]
        out.append((o, holes))
    return out


def point_in_ring(p, ring) -> bool:
    y, x = p
    inside = False
    for (y1, x1), (y2, x2) in zip(ring, ring[1:] + ring[:1]):
        if (y1 > y) != (y2 > y) and x < (x2 - x1) * (y - y1) / (y2 - y1 + 1e-15) + x1:
            inside = not inside
    return inside


# ---- data ---------------------------------------------------------------------------------
def fetch_osm():
    s, w, n, e = FETCH_BOUNDS
    q = OVERPASS_QUERY.format(s=s, w=w, n=n, e=e)
    req = urllib.request.Request("https://overpass-api.de/api/interpreter",
                                 data=urllib.parse.urlencode({"data": q}).encode(), headers=UA)
    with urllib.request.urlopen(req, timeout=200) as r:
        OSM_CACHE.write_bytes(r.read())


def tile_xy(lat, lng, z):
    n = 2 ** z
    x = (lng + 180) / 360 * n
    y = (1 - math.asinh(math.tan(math.radians(lat))) / math.pi) / 2 * n
    return x, y


def fetch_dem():
    from PIL import Image  # noqa: PLC0415

    s, w, n, e = FETCH_BOUNDS
    x0, y0 = (int(v) for v in tile_xy(n, w, DEM_ZOOM))
    x1, y1 = (int(v) for v in tile_xy(s, e, DEM_ZOOM))
    tiles = {}
    for x in range(x0, x1 + 1):
        for y in range(y0, y1 + 1):
            url = f"https://s3.amazonaws.com/elevation-tiles-prod/terrarium/{DEM_ZOOM}/{x}/{y}.png"
            with urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=60) as r:
                im = Image.open(io.BytesIO(r.read())).convert("RGB")
            px = im.load()
            tiles[f"{x}/{y}"] = [[round(px[i, j][0] * 256 + px[i, j][1] + px[i, j][2] / 256 - 32768, 1)
                                  for i in range(256)] for j in range(256)]
    DEM_CACHE.write_text(json.dumps({"zoom": DEM_ZOOM, "tiles": tiles}), encoding="utf-8")


def env_key() -> str | None:
    import os  # noqa: PLC0415

    if k := os.environ.get("GOOGLE_ELEVATION_API_KEY"):
        return k
    env = ROOT / ".env.local"
    if env.exists():
        for line in env.read_text(encoding="utf-8").splitlines():
            if line.startswith("GOOGLE_ELEVATION_API_KEY="):
                return line.split("=", 1)[1].strip() or None
    return None


def _encode_polyline(pts) -> str:
    out, plat, plng = [], 0, 0
    for la, ln in pts:
        ila, iln = round(la * 1e5), round(ln * 1e5)
        for v in (ila - plat, iln - plng):
            v = ~(v << 1) if v < 0 else v << 1
            while v >= 0x20:
                out.append(chr((0x20 | (v & 0x1F)) + 63))
                v >>= 5
            out.append(chr(v + 63))
        plat, plng = ila, iln
    return "".join(out)


def fetch_google_dem(key: str):
    s, w, n, e = FETCH_BOUNDS
    rows = int((n - s) * MY / GDEM_STEP_M) + 1
    cols = int((e - w) * MX / GDEM_STEP_M) + 1
    pts = [(n - (n - s) * j / (rows - 1), w + (e - w) * i / (cols - 1)) for j in range(rows) for i in range(cols)]
    vals = []
    for k in range(0, len(pts), 500):
        chunk = pts[k:k + 500]
        url = ("https://maps.googleapis.com/maps/api/elevation/json?locations=enc:"
               + urllib.parse.quote(_encode_polyline(chunk)) + "&key=" + key)
        with urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=60) as r:
            d = json.load(r)
        if d.get("status") != "OK":
            sys.exit(f"Elevation API: {d.get('status')} {d.get('error_message', '')}")
        vals += [round(x["elevation"], 1) for x in d["results"]]
    GDEM_CACHE.write_text(json.dumps({"bounds": list(FETCH_BOUNDS), "rows": rows, "cols": cols,
                                      "step_m": GDEM_STEP_M, "source": "Google Elevation API",
                                      "z": vals}), encoding="utf-8")


class GridDem:
    """Bilinear lookup over the cached Google Elevation grid (metres)."""

    def __init__(self, path: Path = GDEM_CACHE):
        d = json.loads(path.read_text(encoding="utf-8"))
        self.s, self.w, self.n, self.e = d["bounds"]
        self.rows, self.cols, self.z = d["rows"], d["cols"], d["z"]

    def at(self, lat: float, lng: float) -> float:
        fy = (self.n - lat) / (self.n - self.s) * (self.rows - 1)
        fx = (lng - self.w) / (self.e - self.w) * (self.cols - 1)
        iy = min(max(int(fy), 0), self.rows - 2)
        ix = min(max(int(fx), 0), self.cols - 2)
        ty, tx = fy - iy, fx - ix
        z = lambda j, i: self.z[j * self.cols + i]
        return ((z(iy, ix) * (1 - tx) + z(iy, ix + 1) * tx) * (1 - ty)
                + (z(iy + 1, ix) * (1 - tx) + z(iy + 1, ix + 1) * tx) * ty)


def load_dem():
    """Google grid when cached (or fetchable), else the public terrarium tiles."""
    if GDEM_CACHE.exists():
        return GridDem()
    if DEM_CACHE.exists():
        return Dem()
    return None


class Dem:
    """Bilinear elevation lookup over cached terrarium tiles (metres)."""

    def __init__(self, path: Path = DEM_CACHE):
        d = json.loads(path.read_text(encoding="utf-8"))
        self.z = d["zoom"]
        self.tiles = d["tiles"]

    def _px(self, gx: int, gy: int) -> float:
        t = self.tiles.get(f"{gx // 256}/{gy // 256}")
        if t is None:
            return float("nan")
        return t[gy % 256][gx % 256]

    def at(self, lat: float, lng: float) -> float:
        x, y = tile_xy(lat, lng, self.z)
        gx, gy = x * 256 - 0.5, y * 256 - 0.5
        ix, iy = int(math.floor(gx)), int(math.floor(gy))
        fx, fy = gx - ix, gy - iy
        a, b = self._px(ix, iy), self._px(ix + 1, iy)
        c, d = self._px(ix, iy + 1), self._px(ix + 1, iy + 1)
        return (a * (1 - fx) + b * fx) * (1 - fy) + (c * (1 - fx) + d * fx) * fy


# ---- terrain products ---------------------------------------------------------------------
def grid(dem: Dem, step_m: float):
    s, w, n, e = BOUNDS
    rows = int((n - s) * MY / step_m) + 1
    cols = int((e - w) * MX / step_m) + 1
    lat = [n - (n - s) * j / (rows - 1) for j in range(rows)]
    lng = [w + (e - w) * i / (cols - 1) for i in range(cols)]
    z = [[dem.at(la, ln) for ln in lng] for la in lat]
    return lat, lng, z


def blur(z, passes=2):
    rows, cols = len(z), len(z[0])
    for _ in range(passes):
        nz = [[0.0] * cols for _ in range(rows)]
        for j in range(rows):
            for i in range(cols):
                acc = cnt = 0
                for dj in (-1, 0, 1):
                    for di in (-1, 0, 1):
                        jj, ii = j + dj, i + di
                        if 0 <= jj < rows and 0 <= ii < cols:
                            acc += z[jj][ii]
                            cnt += 1
                nz[j][i] = acc / cnt
        z = nz
    return z


def contours(lat, lng, z) -> list[dict]:
    """Marching squares → chained polylines per level."""
    rows, cols = len(z), len(z[0])
    lo = math.floor(min(min(r) for r in z) / CONTOUR_STEP) * CONTOUR_STEP
    hi = math.ceil(max(max(r) for r in z) / CONTOUR_STEP) * CONTOUR_STEP
    out = []
    for level in range(int(lo), int(hi) + 1, CONTOUR_STEP):
        segs = []
        for j in range(rows - 1):
            for i in range(cols - 1):
                c = [z[j][i], z[j][i + 1], z[j + 1][i + 1], z[j + 1][i]]
                idx = sum(1 << k for k, v in enumerate(c) if v >= level)
                if idx in (0, 15):
                    continue
                corners = [(j, i), (j, i + 1), (j + 1, i + 1), (j + 1, i)]

                def edge(k):
                    a, b = corners[k], corners[(k + 1) % 4]
                    va, vb = c[k], c[(k + 1) % 4]
                    t = (level - va) / (vb - va) if vb != va else 0.5
                    la = lat[a[0]] + (lat[b[0]] - lat[a[0]]) * t
                    ln = lng[a[1]] + (lng[b[1]] - lng[a[1]]) * t
                    return (round(la, 7), round(ln, 7))

                crossing = [k for k in range(4) if (c[k] >= level) != (c[(k + 1) % 4] >= level)]
                if len(crossing) == 2:
                    segs.append((edge(crossing[0]), edge(crossing[1])))
                elif len(crossing) == 4:  # saddle: pair by centre value
                    centre = sum(c) / 4
                    pairs = [(0, 1), (2, 3)] if (centre >= level) == (c[0] >= level) else [(0, 3), (1, 2)]
                    for a, b in pairs:
                        segs.append((edge(crossing[a]), edge(crossing[b])))
        for line in chain(segs):
            if len(line) < 6:
                continue
            closed = line[0] == line[-1]
            line = simplify(line, 3.0)
            line = chaikin(line, 1, closed=False)
            out.append({"e": level, "p": flat(line, 6)})
    return out


def chain(segs):
    from collections import defaultdict

    ends = defaultdict(list)
    for k, (a, b) in enumerate(segs):
        ends[a].append(k)
        ends[b].append(k)
    used = [False] * len(segs)
    lines = []
    for k in range(len(segs)):
        if used[k]:
            continue
        used[k] = True
        a, b = segs[k]
        line = [a, b]
        for forward in (True, False):
            while True:
                tip = line[-1] if forward else line[0]
                nxt = next((m for m in ends[tip] if not used[m]), None)
                if nxt is None:
                    break
                used[nxt] = True
                p, q = segs[nxt]
                other = q if p == tip else p
                if forward:
                    line.append(other)
                else:
                    line.insert(0, other)
        lines.append(line)
    return lines


def hillshade(dem: Dem, out: Path):
    from PIL import Image, ImageFilter  # noqa: PLC0415

    step = 6.0  # metres per pixel
    lat, lng, z = grid(dem, step)
    z = blur(z, 1)
    rows, cols = len(z), len(z[0])
    az, alt = math.radians(315), math.radians(40)
    img = Image.new("RGBA", (cols, rows))
    px = img.load()
    for j in range(rows):
        for i in range(cols):
            zl = z[j][max(i - 1, 0)]
            zr = z[j][min(i + 1, cols - 1)]
            zu = z[max(j - 1, 0)][i]
            zd = z[min(j + 1, rows - 1)][i]
            dzdx = (zr - zl) / (2 * step) * 1.6  # vertical exaggeration
            dzdy = (zd - zu) / (2 * step) * 1.6
            slope = math.atan(math.hypot(dzdx, dzdy))
            aspect = math.atan2(dzdy, -dzdx)
            shade = math.sin(alt) * math.cos(slope) + math.cos(alt) * math.sin(slope) * math.cos(az - aspect)
            v = max(0.0, min(1.0, shade))
            flat_v = math.sin(alt)
            if v < flat_v:  # shadow: deep forest-ink tint, alpha by darkness
                a = int(min(1.0, (flat_v - v) / flat_v * 1.25) * 150)
                px[i, j] = (38, 52, 38, a)
            else:  # light: warm cream highlight
                a = int(min(1.0, (v - flat_v) / (1 - flat_v) * 1.6) * 110)
                px[i, j] = (255, 248, 225, a)
    img = img.filter(ImageFilter.GaussianBlur(0.8))
    img.save(out, optimize=True)
    return [BOUNDS[0], BOUNDS[1], BOUNDS[2], BOUNDS[3]]


# ---- build --------------------------------------------------------------------------------
def build(osm_path: Path = OSM_CACHE, dem=None, with_hillshade: bool = True) -> dict:
    data = json.loads(osm_path.read_text(encoding="utf-8"))
    els = data["elements"]
    land, water, buildings = [], [], []
    waterways, roads, paths, labels = [], [], [], []

    def poly_entry(kind, outer, holes, tol, nd):
        o = simplify(outer, tol)
        if len(o) < 4 or not intersects(o):
            return None
        hs = [flat(simplify(h, tol), nd) for h in holes if len(h) >= 4]
        e = {"k": kind, "r": flat(o, nd)} if kind else {"r": flat(o, nd)}
        if hs:
            e["h"] = hs
        return e

    rings = [o for e in els if e["type"] == "relation" and e.get("tags", {}).get("boundary") == "protected_area"
             for o, _ in polygons(e)]
    boundary = [flat(simplify(o, 4.0), 6) for o in rings]
    coarse = [simplify(o, 25.0) for o in rings]

    def near_park(p, limit_m=BUILDING_BUFFER_M) -> bool:
        if any(point_in_ring(p, r) for r in coarse):
            return True
        for r in coarse:
            for a, b in zip(r, r[1:] + r[:1]):
                ax, ay, bx, by = a[1] * MX, a[0] * MY, b[1] * MX, b[0] * MY
                px, py = p[1] * MX, p[0] * MY
                dx, dy = bx - ax, by - ay
                t = 0.0 if dx == dy == 0 else max(0, min(1, ((px - ax) * dx + (py - ay) * dy) / (dx * dx + dy * dy)))
                if math.hypot(px - ax - t * dx, py - ay - t * dy) <= limit_m:
                    return True
        return False

    for e in els:
        t = e.get("tags", {})
        if e["type"] == "node":
            continue
        if e["type"] == "relation" and t.get("boundary") == "protected_area":
            continue
        kind = next((v for (k, val), v in LANDCOVER.items() if t.get(k) == val), None)
        if kind:
            for o, holes in polygons(e):
                if ring_area(o) < 150:
                    continue
                if ent := poly_entry(kind, o, holes, 3.0, 6):
                    land.append(ent)
            continue
        if t.get("natural") == "water" or t.get("landuse") in ("reservoir", "basin"):
            for o, holes in polygons(e):
                if ent := poly_entry(None, o, holes, 1.5, 6):
                    water.append(ent)
                    if t.get("name"):
                        c = (sum(p[0] for p in o) / len(o), sum(p[1] for p in o) / len(o))
                        labels.append({"t": t["name"], "k": "water", "p": [round(c[0], 6), round(c[1], 6)]})
            continue
        if e["type"] != "way":
            continue
        g = geom(e)
        if len(g) < 2 or not intersects(g):
            continue
        if "building" in t:
            if len(g) >= 4 and ring_area(g) >= 12 and near_park(g[0]):
                buildings.append(flat(simplify(g, 1.2), 6))
        elif t.get("waterway") in WATERWAYS:
            ent = {"k": t["waterway"], "p": flat(simplify(g, 2.0), 6)}
            if t.get("name"):
                ent["n"] = t["name"]
            waterways.append(ent)
        elif t.get("highway") in ROADS:
            ent = {"k": t["highway"], "p": flat(simplify(g, 1.5), 6)}
            if t.get("name"):
                ent["n"] = t["name"]
            roads.append(ent)
        elif t.get("highway") in PATHS:
            paths.append({"k": "steps" if t["highway"] == "steps" else t["highway"], "p": flat(simplify(g, 1.0), 6)})

    # big areas first so small ones draw on top
    land.sort(key=lambda x: -ring_area(list(zip(x["r"][0::2], x["r"][1::2]))))
    out = {
        "version": 1,
        "bounds": list(BOUNDS),
        "sources": ["© OpenStreetMap contributors (ODbL)", "Elevasi: Google" if GDEM_CACHE.exists() else "Terrain: AWS Terrain Tiles / Mapzen (SRTM)"],
        "landcover": land, "water": water, "boundary": boundary, "buildings": buildings,
        "waterways": waterways, "roads": roads, "paths": paths, "labels": labels,
        "contours": [], "contour_step": CONTOUR_STEP, "index_step": INDEX_STEP,
    }
    if dem is not None:
        lat, lng, z = grid(dem, 15.0)
        out["contours"] = contours(lat, lng, blur(z, 2))
        if with_hillshade:
            OUT_DIR.mkdir(parents=True, exist_ok=True)
            out["hillshade"] = {"file": "hillshade.png", "bounds": hillshade(dem, OUT_DIR / "hillshade.png")}
    return out


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--refresh", action="store_true", help="re-download OSM + terrain")
    args = ap.parse_args(argv)
    OSM_DIR.mkdir(parents=True, exist_ok=True)
    if args.refresh or not OSM_CACHE.exists():
        print("downloading OSM (Overpass) …")
        fetch_osm()
    key = env_key()
    if key and (args.refresh or not GDEM_CACHE.exists()):
        print("downloading Google Elevation grid …")
        fetch_google_dem(key)
    elif not key and (args.refresh or not DEM_CACHE.exists()):
        print("no GOOGLE_ELEVATION_API_KEY: downloading public terrain tiles …")
        fetch_dem()
    dem = load_dem()
    print(f"terrain: {type(dem).__name__}")
    out = build(dem=dem)
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    path = OUT_DIR / "basemap.json"
    path.write_text(json.dumps(out, separators=(",", ":"), ensure_ascii=False), encoding="utf-8")
    counts = {k: len(v) for k, v in out.items() if isinstance(v, list) and k not in ("bounds", "sources")}
    print(f"wrote {path.relative_to(ROOT)} ({path.stat().st_size / 1e6:.2f} MB): {counts}")
    if (OUT_DIR / "hillshade.png").exists():
        print(f"wrote assets/map/hillshade.png ({(OUT_DIR / 'hillshade.png').stat().st_size / 1e6:.2f} MB)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
