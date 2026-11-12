"""Validate assets/content/*.json before merge (run locally and in CI).

Errors (exit 1): broken structure, duplicate/unknown IDs, missing files, bad radius, disconnected graph.
Warnings (exit 0): dummy data, [ISI] placeholder texts, missing photos/audio/sources.
The word-count rule (80–150) is only enforced on texts that are no longer placeholders.

Usage:  python tools/validate_content.py
"""

import json
import sys
from collections import deque
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CONTENT = ROOT / "assets" / "content"
IMAGES = ROOT / "assets" / "images"
AUDIO = ROOT / "assets" / "audio"

errors: list[str] = []
warnings: list[str] = []


def load(name: str) -> dict:
    path = CONTENT / name
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError:
        errors.append(f"{name}: missing")
    except json.JSONDecodeError as e:
        errors.append(f"{name}: invalid JSON ({e})")
    return {}


pois_f, fac_f, routes_f = load("pois.json"), load("facilities.json"), load("routes.json")
park, graph = load("park.json"), load("trail_graph.json")
if errors:
    print("\n".join(f"ERROR   {e}" for e in errors))
    sys.exit(1)

for name, f in [("pois.json", pois_f), ("facilities.json", fac_f), ("routes.json", routes_f),
                ("park.json", park), ("trail_graph.json", graph)]:
    if f.get("dummy"):
        warnings.append(f"{name}: DUMMY data — replace with survey data")

pois = pois_f.get("pois", [])
facilities = fac_f.get("facilities", [])
routes = routes_f.get("routes", [])
nodes = {n["id"]: n for n in graph.get("nodes", [])}

# ---- IDs ---------------------------------------------------------------------------------
ids = [p["id"] for p in pois] + [f["id"] for f in facilities]
dupes = {i for i in ids if ids.count(i) > 1}
if dupes:
    errors.append(f"duplicate ids: {sorted(dupes)}")
route_ids = {r["id"] for r in routes}
poi_ids = {p["id"] for p in pois}

# ---- POIs --------------------------------------------------------------------------------
CATEGORIES = {"informasi", "sejarah", "alam", "rekreasi"}
for p in pois:
    pid = p.get("id", "?")
    for key in ("name", "category", "lat", "lng", "radius_m", "trigger", "visit_minutes", "graph_node", "text"):
        if key not in p:
            errors.append(f"{pid}: missing field '{key}'")
    if p.get("category") not in CATEGORIES:
        errors.append(f"{pid}: unknown category '{p.get('category')}'")
    if not 15 <= p.get("radius_m", 0) <= 50:
        errors.append(f"{pid}: radius_m {p.get('radius_m')} outside 15–50")
    if "qr" in p.get("trigger", []) and p.get("qr_code") != f"jelajahtaman://poi/{pid}":
        errors.append(f"{pid}: qr trigger but qr_code is not jelajahtaman://poi/{pid}")
    if p.get("graph_node") not in nodes:
        errors.append(f"{pid}: graph_node '{p.get('graph_node')}' not in trail_graph")
    for r in p.get("routes", []):
        if r not in route_ids:
            errors.append(f"{pid}: unknown route '{r}'")
    if p.get("coord_source") == "DUMMY":
        warnings.append(f"{pid}: dummy coordinates")
    text = p.get("text") or ""
    if text.startswith("[ISI]"):
        warnings.append(f"{pid}: text placeholder")
        if p.get("draft_text"):
            if not (pois_f.get("dummy") is True):
                errors.append(f"{pid}: draft_text (unverified UI mock copy) is only allowed in dummy content")
            warnings.append(f"{pid}: showing unverified draft_text (observational mock copy)")
    else:
        words = len(text.split())
        if not 80 <= words <= 150:
            errors.append(f"{pid}: text has {words} words (must be 80–150)")
        if not p.get("sources"):
            errors.append(f"{pid}: real text but no 'sources' (PRD §8.2: no fact without a source)")
    if not p.get("images"):
        warnings.append(f"{pid}: no images")
    for img in p.get("images", []):
        if not (IMAGES / img).exists():
            errors.append(f"{pid}: image file missing assets/images/{img}")
    if p.get("audio"):
        if not (AUDIO / p["audio"]).exists():
            errors.append(f"{pid}: audio file missing assets/audio/{p['audio']}")
    else:
        warnings.append(f"{pid}: no audio (TTS fallback)")

# ---- facilities --------------------------------------------------------------------------
FAC_TYPES = {"toilet", "musala", "warung", "pos_petugas", "istirahat"}
for f in facilities:
    if f.get("type") not in FAC_TYPES:
        errors.append(f"{f.get('id')}: unknown facility type '{f.get('type')}'")
    if f.get("graph_node") not in nodes:
        errors.append(f"{f.get('id')}: graph_node not in trail_graph")
    for img in f.get("images", []):
        if not (IMAGES / img).exists():
            errors.append(f"{f.get('id')}: image file missing assets/images/{img}")

# ---- routes ------------------------------------------------------------------------------
for r in routes:
    for pid in r.get("poi_sequence", []):
        if pid not in poi_ids:
            errors.append(f"route {r['id']}: unknown POI {pid}")
    for nid in r.get("node_path", []):
        if nid not in nodes:
            errors.append(f"route {r['id']}: unknown node {nid}")

# ---- park --------------------------------------------------------------------------------
if park.get("gate_poi") not in poi_ids:
    errors.append("park.json: gate_poi is not a POI")
if not park.get("hours", {}).get("verified"):
    warnings.append("park.json: opening hours not verified [VERIFIKASI]")

# ---- graph -------------------------------------------------------------------------------
adj = {nid: set() for nid in nodes}
for e in graph.get("edges", []):
    a, b = e.get("from"), e.get("to")
    if a not in nodes or b not in nodes:
        errors.append(f"edge {a}->{b}: unknown node")
        continue
    if e.get("length_m", 0) <= 0:
        errors.append(f"edge {a}->{b}: length_m must be > 0")
    adj[a].add(b)
    adj[b].add(a)
gate_node = next((p["graph_node"] for p in pois if p["id"] == park.get("gate_poi")), None)
if gate_node in adj:
    seen, q = {gate_node}, deque([gate_node])
    while q:
        for v in adj[q.popleft()]:
            if v not in seen:
                seen.add(v)
                q.append(v)
    unreachable = sorted(set(nodes) - seen)
    if unreachable:
        errors.append(f"graph: nodes unreachable from gate: {unreachable}")

# ---- report ------------------------------------------------------------------------------
for w in warnings:
    print(f"WARNING {w}")
for e in errors:
    print(f"ERROR   {e}")
print(f"\n{len(errors)} error(s), {len(warnings)} warning(s)")
sys.exit(1 if errors else 0)
