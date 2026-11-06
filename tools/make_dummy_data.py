"""Generate DUMMY content files in assets/content/ so development can start before the survey.

Every coordinate, distance, elevation and duration produced here is FAKE.
- Every record carries "coord_source": "DUMMY" (POIs/facilities/nodes) or "dummy": true (files).
- Positions are a synthetic layout in metres around an arbitrary anchor, NOT surveyed points.
- Texts are "[ISI]" placeholders. No historical or location facts are invented.

Replace with real survey data (see docs/engineering/SURVEY_CHECKLIST.md). Once real data exists,
delete this script so nobody regenerates dummy data over the real files.

Usage:  python tools/make_dummy_data.py
"""

import json
import math
from pathlib import Path

OUT = Path(__file__).resolve().parent.parent / "assets" / "content"

# Arbitrary anchor for the synthetic layout. NOT a surveyed coordinate. [VERIFIKASI]
ANCHOR_LAT, ANCHOR_LNG = -6.8580, 107.6330
EARTH_R = 6371000.0


def to_latlng(x_m: float, y_m: float) -> tuple[float, float]:
    """x = metres east, y = metres north of the anchor."""
    lat = ANCHOR_LAT + (y_m / EARTH_R) * 180 / math.pi
    lng = ANCHOR_LNG + (x_m / (EARTH_R * math.cos(math.radians(ANCHOR_LAT)))) * 180 / math.pi
    return round(lat, 6), round(lng, 6)


def haversine(a, b) -> float:
    lat1, lng1, lat2, lng2 = map(math.radians, (a[0], a[1], b[0], b[1]))
    h = math.sin((lat2 - lat1) / 2) ** 2 + math.cos(lat1) * math.cos(lat2) * math.sin((lng2 - lng1) / 2) ** 2
    return 2 * EARTH_R * math.asin(math.sqrt(h))


def elevation(y_m: float) -> float:
    return round(800 + y_m * 0.08, 1)  # fake: terrain rises to the north


# ---- synthetic layout (metres) -------------------------------------------------------------
# id, name, category, x, y, radius, triggers, visit_min, difficulty, routes
POIS = [
    ("P01", "Gerbang Dago Pakar", "informasi", 0, 0, 30, ["gps"], 5, 1, ["santai", "sedang", "trekking"]),
    ("P02", "Monumen Ir. H. Djuanda", "sejarah", 60, 260, 25, ["gps"], 10, 1, ["santai", "sedang", "trekking"]),
    ("P03", "Museum Ir. H. Djuanda", "sejarah", 120, 330, 25, ["gps"], 20, 1, ["santai", "sedang", "trekking"]),
    ("P04", "Kolam Pakar", "alam", 250, 500, 30, ["gps"], 10, 1, ["santai", "sedang", "trekking"]),
    ("P05", "Gua Jepang", "sejarah", 250, 850, 20, ["gps", "qr"], 15, 2, ["santai", "sedang", "trekking"]),
    ("P06", "Gua Belanda", "sejarah", 550, 1100, 20, ["gps", "qr"], 20, 2, ["santai", "sedang", "trekking"]),
    ("P07", "Penangkaran Rusa", "alam", 700, 1300, 30, ["gps"], 10, 2, ["sedang", "trekking"]),
    ("P08", "Kawasan Hutan Pinus", "alam", 0, 620, 40, ["gps"], 15, 1, ["sedang", "trekking"]),
    ("P09", "Area Rumput / Piknik", "rekreasi", -100, 760, 40, ["gps"], 15, 1, ["sedang", "trekking"]),
    ("P10", "Titik Koleksi Flora", "alam", -150, 300, 25, ["gps"], 10, 1, ["sedang", "trekking"]),
    ("P11", "Curug Omas", "alam", 1200, 2300, 40, ["gps"], 20, 3, ["trekking"]),
]
KEYWORDS = {
    "P01": ["gerbang", "pintu masuk", "dago pakar"], "P02": ["monumen", "djuanda", "juanda"],
    "P03": ["museum", "djuanda", "juanda"], "P04": ["kolam", "pakar", "danau"],
    "P05": ["gua", "goa", "jepang"], "P06": ["gua", "goa", "belanda"], "P07": ["rusa", "penangkaran", "satwa"],
    "P08": ["pinus", "hutan"], "P09": ["piknik", "rumput", "taman"], "P10": ["flora", "tanaman", "koleksi"],
    "P11": ["curug", "air terjun", "omas"],
}
FACILITIES = [
    ("FS01", "toilet", "Toilet dekat Gerbang", 30, -20, ["toilet", "wc", "kamar mandi"]),
    ("FS02", "musala", "Musala", -40, 210, ["musala", "mushola", "masjid", "salat", "sholat"]),
    ("FS03", "warung", "Warung dekat Kolam", 270, 525, ["warung", "kios", "makan", "minum", "jajan"]),
    ("FS04", "pos_petugas", "Pos Petugas", 570, 1075, ["pos", "petugas", "informasi", "bantuan"]),
    ("FS05", "istirahat", "Bangku Hutan Pinus", 20, 640, ["istirahat", "bangku", "duduk"]),
]
JUNCTIONS = [("J01", 0, 200), ("J02", 150, 450), ("J03", 300, 700), ("J04", 400, 900)]
# undirected edges between node ids (POI node = N_<id>, facility node = N_<id>)
EDGES = [
    ("N_P01", "J01"), ("N_P01", "N_FS01"), ("J01", "N_P02"), ("J01", "N_FS02"), ("J01", "N_P10"),
    ("N_P02", "N_P03"), ("N_P03", "J02"), ("J02", "N_P04"), ("N_P04", "N_FS03"), ("N_P04", "J03"),
    ("J02", "N_P08"), ("N_P08", "N_FS05"), ("N_P08", "N_P09"), ("N_P09", "J03"),
    ("J03", "N_P05"), ("N_P05", "J04"), ("J04", "N_P06"), ("N_P06", "N_FS04"), ("N_P06", "N_P07"),
    ("N_P07", "N_P11"), ("N_P10", "N_P08"),
]
ROUTES = [
    ("santai", "Santai", 1, ["P01", "P02", "P03", "P04", "P05", "P06", "P01"]),
    ("sedang", "Sedang", 2, ["P01", "P10", "P02", "P03", "P04", "P08", "P09", "P05", "P06", "P07", "P01"]),
    ("trekking", "Trekking", 3, ["P01", "P10", "P02", "P03", "P08", "P09", "P04", "P05", "P06", "P07", "P11", "P01"]),
]

# ---- build ---------------------------------------------------------------------------------
nodes = {}
for pid, _, _, x, y, *_ in POIS:
    nodes[f"N_{pid}"] = {"id": f"N_{pid}", "x": x, "y": y, "ref": pid}
for fid, _, _, x, y, _ in FACILITIES:
    nodes[f"N_{fid}"] = {"id": f"N_{fid}", "x": x, "y": y, "ref": fid}
for jid, x, y in JUNCTIONS:
    nodes[jid] = {"id": jid, "x": x, "y": y, "ref": None}

graph_nodes = []
for n in nodes.values():
    lat, lng = to_latlng(n["x"], n["y"])
    n["lat"], n["lng"], n["ele"] = lat, lng, elevation(n["y"])
    graph_nodes.append({"id": n["id"], "lat": lat, "lng": lng, "ele": n["ele"], "ref": n["ref"],
                        "coord_source": "DUMMY"})

graph_edges = []
adj = {nid: [] for nid in nodes}
for a, b in EDGES:
    na, nb = nodes[a], nodes[b]
    length = round(haversine((na["lat"], na["lng"]), (nb["lat"], nb["lng"])), 1)
    d_ele = nb["ele"] - na["ele"]
    graph_edges.append({"from": a, "to": b, "length_m": length,
                        "ascent_m": round(max(d_ele, 0), 1), "descent_m": round(max(-d_ele, 0), 1),
                        "geometry": [[na["lat"], na["lng"]], [nb["lat"], nb["lng"]]]})
    adj[a].append((b, length, max(d_ele, 0)))
    adj[b].append((a, length, max(-d_ele, 0)))


def shortest(src: str, dst: str):
    """Plain Dijkstra on length; returns (path, length_m, ascent_m). Used only to fill route totals."""
    import heapq
    dist, prev, asc = {src: 0.0}, {}, {src: 0.0}
    pq = [(0.0, src)]
    while pq:
        d, u = heapq.heappop(pq)
        if u == dst:
            break
        if d > dist.get(u, math.inf):
            continue
        for v, w, up in adj[u]:
            nd = d + w
            if nd < dist.get(v, math.inf):
                dist[v], prev[v], asc[v] = nd, u, asc[u] + up
                heapq.heappush(pq, (nd, v))
    path, cur = [dst], dst
    while cur != src:
        cur = prev[cur]
        path.append(cur)
    return path[::-1], dist[dst], asc[dst]


# connectivity check (same rule as PB12 done criterion)
for nid in nodes:
    shortest("N_P01", nid)

routes_out = []
for rid, name, diff, seq in ROUTES:
    node_path, total_len, total_asc = [], 0.0, 0.0
    for a, b in zip(seq, seq[1:]):
        p, l, up = shortest(f"N_{a}", f"N_{b}")
        node_path += p if not node_path else p[1:]
        total_len += l
        total_asc += up
    walk_min = total_len / 50 + total_asc / 10
    visit_min = sum(p[7] for p in POIS if p[0] in set(seq))
    routes_out.append({"id": rid, "name": name, "difficulty": diff,
                       "distance_m": round(total_len), "ascent_m": round(total_asc),
                       "duration_min": round(walk_min + visit_min),
                       "poi_sequence": seq, "node_path": node_path})

pois_out = []
for pid, name, cat, x, y, r, trig, visit, diff, routes in POIS:
    n = nodes[f"N_{pid}"]
    pois_out.append({
        "id": pid, "name": name, "category": cat, "lat": n["lat"], "lng": n["lng"], "coord_source": "DUMMY",
        "radius_m": r, "trigger": trig, "qr_code": f"jelajahtaman://poi/{pid}" if "qr" in trig else None,
        "visit_minutes": visit, "difficulty": diff, "graph_node": f"N_{pid}", "keywords": KEYWORDS[pid],
        "text": f"[ISI] Teks {name} (80–150 kata) dari sumber resmi/papan informasi.",
        "key_facts": [], "images": [], "audio": None, "audio_seconds": None,
        "routes": routes, "safety_note": None, "sources": [],
    })

facilities_out = []
for fid, ftype, name, x, y, kw in FACILITIES:
    n = nodes[f"N_{fid}"]
    facilities_out.append({"id": fid, "type": ftype, "name": name, "lat": n["lat"], "lng": n["lng"],
                           "coord_source": "DUMMY", "graph_node": f"N_{fid}", "keywords": kw})

park_out = {
    "dummy": True,
    "hours": {"open": "08:00", "close": "16:00", "verified": False},
    "gate_poi": "P01",
    "params": {
        "gps_interval_s": 3, "gps_weak_accuracy_m": 30, "gps_weak_banner_after_s": 60,
        "approach_margin_m": 30, "approach_exit_margin_m": 40,
        "debounce_readings": 2, "retrigger_exit_margin_m": 15, "cooldown_min": 10,
        "arrival_m": 15, "offroute_m": 30, "offroute_readings": 2,
        "walk_speed_m_per_min": 50, "ascent_min_per_10m": 1,
        "closing_buffer_min": 15, "hydration_default_min": 45,
        "rec_weights": {"dist": 0.50, "interest": 0.25, "route": 0.15, "difficulty": 0.10},
    },
}

OUT.mkdir(parents=True, exist_ok=True)
files = {
    "pois.json": {"version": 1, "dummy": True, "pois": pois_out},
    "facilities.json": {"version": 1, "dummy": True, "facilities": facilities_out},
    "routes.json": {"version": 1, "dummy": True, "routes": routes_out},
    "park.json": park_out,
    "trail_graph.json": {"version": 1, "dummy": True, "nodes": graph_nodes, "edges": graph_edges},
}
for name, data in files.items():
    (OUT / name).write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"wrote {OUT / name}")
for r in routes_out:
    print(f"  route {r['id']}: {r['distance_m']} m, +{r['ascent_m']} m, ~{r['duration_min']} min (DUMMY)")
