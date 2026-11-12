"""Build assets/content/trail_graph.json (and route node paths) from OpenStreetMap footpaths.

Walkable OSM ways (path, footway, steps, track, pedestrian everywhere near the park; service,
unclassified, residential, living_street only inside the Tahura boundary + 50 m) are split at
shared OSM nodes into graph edges. Every POI and facility is attached to its nearest trail point
by splitting that edge (warning > 25 m, error > 100 m). Only the component connected to the
gate is kept. Elevation comes from the terrain grid built by tools/osm_to_basemap.py, so the
slope ETA (D09) works.

The survey-GPX pipeline (tools/gpx_to_graph.py) stays available for refining trails later.

Usage:  python3 tools/osm_to_graph.py [--update-routes] [--dry-run]
"""

from __future__ import annotations

import argparse
import heapq
import json
import math
import sys
from collections import defaultdict, deque
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import osm_to_basemap as basemap  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
CONTENT = ROOT / "assets" / "content"
GEOJSON = ROOT / "survey" / "raw" / "osm" / "trail_graph.geojson"

PATH_TYPES = {"path", "footway", "steps", "track", "pedestrian", "bridleway"}
ROAD_TYPES = {"service", "unclassified", "residential", "living_street"}
PATH_BUFFER_M = 150
ROAD_BUFFER_M = 50
WARN_ATTACH_M, ERROR_ATTACH_M = 25, 100

# Route POI order on the real layout (gate in the SW, valley runs NE to Curug Omas).
ROUTE_SEQUENCES = {
    "santai": ["P01", "P03", "P02", "P04", "P05", "P06", "P01"],
    "sedang": ["P01", "P10", "P03", "P02", "P04", "P05", "P08", "P06", "P07", "P09", "P01"],
    "trekking": ["P01", "P10", "P03", "P02", "P04", "P05", "P08", "P06", "P07", "P09", "P11", "P01"],
}

MY = 111320.0


def mx(lat: float) -> float:
    return 111320.0 * math.cos(math.radians(lat))


def hav(a, b) -> float:
    r = 6371008.8
    p1, p2 = math.radians(a[0]), math.radians(b[0])
    h = math.sin((p2 - p1) / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(math.radians(b[1] - a[1]) / 2) ** 2
    return 2 * r * math.asin(math.sqrt(h))


def poly_len(pts) -> float:
    return sum(hav(a, b) for a, b in zip(pts, pts[1:]))


def project(p, a, b):
    """Closest point to p on segment ab → (point, t, distance m)."""
    k = mx(p[0])
    ax, ay, bx, by = a[1] * k, a[0] * MY, b[1] * k, b[0] * MY
    px, py = p[1] * k, p[0] * MY
    dx, dy = bx - ax, by - ay
    t = 0.0 if dx == dy == 0 else max(0.0, min(1.0, ((px - ax) * dx + (py - ay) * dy) / (dx * dx + dy * dy)))
    q = (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t)
    return q, t, hav(p, q)


# ---- boundary -------------------------------------------------------------------------------
class Boundary:
    def __init__(self, rings):
        self.rings = rings

    def inside(self, p) -> bool:
        return any(basemap.point_in_ring(p, r) for r in self.rings)

    def dist(self, p) -> float:
        if self.inside(p):
            return 0.0
        return min(project(p, a, b)[2] for r in self.rings for a, b in zip(r, r[1:] + r[:1]))


def load_ways(osm: dict, boundary: Boundary):
    ways = []
    for e in osm["elements"]:
        if e["type"] != "way":
            continue
        hw = e.get("tags", {}).get("highway")
        if hw not in PATH_TYPES | ROAD_TYPES or e.get("tags", {}).get("access") in ("private", "no"):
            continue
        pts = [(g["lat"], g["lon"]) for g in e["geometry"]]
        mid = pts[len(pts) // 2]
        buf = PATH_BUFFER_M if hw in PATH_TYPES else ROAD_BUFFER_M
        if min(boundary.dist(mid), boundary.dist(pts[0]), boundary.dist(pts[-1])) > buf:
            continue
        # clip to the basemap extent: the map can't show (or clamp the camera to) anything beyond
        s, w, n, ea = basemap.BOUNDS
        run_nodes, run_pts = [], []
        for nid, p in list(zip(e["nodes"], pts)) + [(None, None)]:
            if p is not None and s <= p[0] <= n and w <= p[1] <= ea:
                run_nodes.append(nid)
                run_pts.append(p)
                continue
            if len(run_nodes) >= 2:
                ways.append((e["id"], hw, run_nodes, run_pts))
            run_nodes, run_pts = [], []
    return ways


# ---- graph ----------------------------------------------------------------------------------
class Graph:
    def __init__(self):
        self.pos: dict[str, tuple[float, float]] = {}
        self.edges: dict[int, dict] = {}  # id → {a, b, geom, kind}
        self.adj: dict[str, set[int]] = defaultdict(set)
        self._next = 0

    def add_edge(self, a: str, b: str, geom, kind: str) -> int:
        eid = self._next
        self._next += 1
        self.edges[eid] = {"a": a, "b": b, "geom": geom, "kind": kind}
        self.adj[a].add(eid)
        self.adj[b].add(eid)
        return eid

    def remove_edge(self, eid: int):
        e = self.edges.pop(eid)
        self.adj[e["a"]].discard(eid)
        self.adj[e["b"]].discard(eid)


def build(ways) -> Graph:
    use = defaultdict(int)
    for _, _, nodes, _ in ways:
        for n in set(nodes):
            use[n] += 1
        use[nodes[0]] += 1
        use[nodes[-1]] += 1
    g = Graph()
    for _, hw, nodes, pts in ways:
        start = 0
        for i in range(1, len(nodes)):
            if use[nodes[i]] >= 2 or i == len(nodes) - 1:
                a, b = f"o{nodes[start]}", f"o{nodes[i]}"
                g.pos[a], g.pos[b] = pts[start], pts[i]
                if a != b:
                    g.add_edge(a, b, pts[start:i + 1], hw)
                start = i
    return g


def attach(g: Graph, item_id: str, node_id: str, p) -> float:
    best = None
    for eid, e in g.edges.items():
        geom = e["geom"]
        for k in range(len(geom) - 1):
            q, t, d = project(p, geom[k], geom[k + 1])
            if best is None or d < best[0]:
                best = (d, eid, k, q)
    d, eid, k, q = best
    e = g.edges[eid]
    g.pos[node_id] = q
    first = e["geom"][:k + 1] + [q]
    second = [q] + e["geom"][k + 1:]
    g.remove_edge(eid)
    if poly_len(first) < 0.05:  # landed on the start node
        g.add_edge(e["a"], node_id, [e["geom"][0], q], e["kind"])
        g.add_edge(node_id, e["b"], second, e["kind"])
    elif poly_len(second) < 0.05:
        g.add_edge(e["a"], node_id, first, e["kind"])
        g.add_edge(node_id, e["b"], [q, e["geom"][-1]], e["kind"])
    else:
        g.add_edge(e["a"], node_id, first, e["kind"])
        g.add_edge(node_id, e["b"], second, e["kind"])
    return d


def component(g: Graph, start: str) -> set[str]:
    seen, q = {start}, deque([start])
    while q:
        u = q.popleft()
        for eid in g.adj[u]:
            e = g.edges[eid]
            v = e["b"] if e["a"] == u else e["a"]
            if v not in seen:
                seen.add(v)
                q.append(v)
    return seen


def prune_spurs(g: Graph, keep: set[str], min_m: float = 25.0):
    """Drop short dead-end stubs (OSM fragments) that lead to no POI/facility."""
    changed = True
    while changed:
        changed = False
        for n in list(g.adj):
            if n in keep or len(g.adj[n]) != 1:
                continue
            eid = next(iter(g.adj[n]))
            if poly_len(g.edges[eid]["geom"]) < min_m:
                g.remove_edge(eid)
                del g.adj[n]
                changed = True


def climb(pts, dem, step=10.0, window=5, gate=3.0) -> tuple[float, float]:
    """Ascent/descent along a polyline on the terrain grid.

    Sampled every `step` m, smoothed over `window` samples (the path hugs steep valley walls, so
    raw grid values zig-zag) and counted with a `gate` m hysteresis, like gpx_to_graph.climb.
    """
    samples = [pts[0]]
    for a, b in zip(pts, pts[1:]):
        n = max(1, int(hav(a, b) // step))
        samples += [(a[0] + (b[0] - a[0]) * i / n, a[1] + (b[1] - a[1]) * i / n) for i in range(1, n + 1)]
    raw = [dem.at(*p) for p in samples]
    h = window // 2
    z = [sum(raw[max(0, i - h):i + h + 1]) / len(raw[max(0, i - h):i + h + 1]) for i in range(len(raw))]
    up = down = 0.0
    anchor = z[0]
    for v in z[1:]:
        if v - anchor >= gate:
            up += v - anchor
            anchor = v
        elif anchor - v >= gate:
            down += anchor - v
            anchor = v
    # whatever is left below the gate still counts towards the net change
    if z[-1] > anchor:
        up += z[-1] - anchor
    else:
        down += anchor - z[-1]
    return up, down


def dijkstra(adj: dict, start: str, goal: str):
    dist = {start: 0.0}
    prev: dict[str, str] = {}
    pq = [(0.0, start)]
    while pq:
        d, u = heapq.heappop(pq)
        if u == goal:
            break
        if d > dist[u]:
            continue
        for v, w in adj[u]:
            nd = d + w
            if nd < dist.get(v, math.inf):
                dist[v], prev[v] = nd, u
                heapq.heappush(pq, (nd, v))
    if goal not in dist:
        return None
    path = [goal]
    while path[-1] != start:
        path.append(prev[path[-1]])
    return path[::-1]


# ---- main -----------------------------------------------------------------------------------
def run(osm_path: Path, content_dir: Path, dem, update_routes: bool = False):
    osm = json.loads(osm_path.read_text(encoding="utf-8"))
    rings = []
    for e in osm["elements"]:
        if e["type"] == "relation" and e.get("tags", {}).get("boundary") == "protected_area":
            rings += [o for o, _ in basemap.polygons(e)]
    boundary = Boundary(rings)
    pois = json.loads((content_dir / "pois.json").read_text(encoding="utf-8"))
    facs = json.loads((content_dir / "facilities.json").read_text(encoding="utf-8"))
    park = json.loads((content_dir / "park.json").read_text(encoding="utf-8"))
    items = [(p["id"], f"N_{p['id']}", (p["lat"], p["lng"])) for p in pois["pois"]]
    items += [(f["id"], f"N_{f['id']}", (f["lat"], f["lng"])) for f in facs["facilities"]]
    log, errors = [], []

    g = build(load_ways(osm, boundary))
    for iid, nid, p in items:
        d = attach(g, iid, nid, p)
        msg = f"{iid}: attached {d:.0f} m from its coordinate"
        if d > ERROR_ATTACH_M:
            errors.append(msg)
        elif d > WARN_ATTACH_M:
            log.append("WARN  " + msg)
    gate = f"N_{park['gate_poi']}"
    keep = component(g, gate)
    for eid in [k for k, e in g.edges.items() if e["a"] not in keep]:
        g.remove_edge(eid)
    for iid, nid, _ in items:
        if nid not in keep:
            errors.append(f"{iid}: not connected to the gate")
    item_nodes = {nid for _, nid, _ in items}
    prune_spurs(g, item_nodes)

    # name junctions J001… in BFS order from the gate, items keep N_<id>
    order, seen, q = [], {gate}, deque([gate])
    while q:
        u = q.popleft()
        order.append(u)
        for eid in sorted(g.adj[u]):
            e = g.edges[eid]
            v = e["b"] if e["a"] == u else e["a"]
            if v not in seen:
                seen.add(v)
                q.append(v)
    names, k = {}, 0
    ref_of = {nid: iid for iid, nid, _ in items}
    for n in order:
        if n in item_nodes:
            names[n] = n
        else:
            k += 1
            names[n] = f"J{k:03d}"

    nodes_json = [{"id": names[n], "lat": round(g.pos[n][0], 6), "lng": round(g.pos[n][1], 6),
                   "ele": round(dem.at(*g.pos[n]), 1), "ref": ref_of.get(n), "coord_source": "OSM"}
                  for n in order]
    edges_json, adj = [], defaultdict(list)
    edge_by_pair = {}
    for eid in sorted(g.edges):
        e = g.edges[eid]
        if e["a"] not in names or e["b"] not in names:
            continue
        up, down = climb(e["geom"], dem)
        ej = {"from": names[e["a"]], "to": names[e["b"]], "length_m": round(poly_len(e["geom"]), 1),
              "ascent_m": round(up, 1), "descent_m": round(down, 1), "kind": e["kind"],
              "geometry": [[round(la, 6), round(ln, 6)] for la, ln in e["geom"]]}
        edges_json.append(ej)
        # Dijkstra on walking time (D09): 50 m/min + 1 min per 10 m of ascent in that direction
        speed = park["params"]["walk_speed_m_per_min"]
        per10 = park["params"]["ascent_min_per_10m"]
        for a, b, asc in ((ej["from"], ej["to"], up), (ej["to"], ej["from"], down)):
            w = ej["length_m"] / speed + asc / 10 * per10
            if (a, b) not in edge_by_pair or edge_by_pair[(a, b)]["length_m"] > ej["length_m"]:
                adj[a].append((b, w))
                edge_by_pair[(a, b)] = ej

    graph_json = {"version": 1, "dummy": False, "source": "OpenStreetMap (ODbL) via tools/osm_to_graph.py",
                  "nodes": nodes_json, "edges": edges_json}

    routes_json = None
    if update_routes:
        routes_json = json.loads((content_dir / "routes.json").read_text(encoding="utf-8"))
        visit = {p["id"]: p["visit_minutes"] for p in pois["pois"]}
        member = defaultdict(list)
        for r in routes_json["routes"]:
            seq = ROUTE_SEQUENCES[r["id"]]
            path = []
            for a, b in zip(seq, seq[1:]):
                leg = dijkstra(adj, f"N_{a}", f"N_{b}")
                if leg is None:
                    errors.append(f"route {r['id']}: no path {a} → {b}")
                    break
                path += leg if not path else leg[1:]
            length = sum(edge_by_pair[(a, b)]["length_m"] for a, b in zip(path, path[1:]))
            ascent = sum((lambda e: e["ascent_m"] if e["from"] == a else e["descent_m"])(edge_by_pair[(a, b)])
                         for a, b in zip(path, path[1:]))
            walk = length / park["params"]["walk_speed_m_per_min"] + ascent / 10 * park["params"]["ascent_min_per_10m"]
            dur = round(walk + sum(visit[p] for p in set(seq)))
            log.append(f"route {r['id']}: {r.get('distance_m')} m → {length:.0f} m, ascent "
                       f"{r.get('ascent_m')} → {ascent:.0f} m, duration {r.get('duration_min')} → {dur} min")
            r.update({"poi_sequence": seq, "node_path": path, "distance_m": round(length),
                      "ascent_m": round(ascent), "duration_min": dur})
            for pid in set(seq):
                member[pid].append(r["id"])
        routes_json["dummy"] = False
        order_ids = [r["id"] for r in routes_json["routes"]]
        for p in pois["pois"]:
            p["routes"] = [rid for rid in order_ids if rid in member[p["id"]]]
    return graph_json, routes_json, pois, log, errors


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--update-routes", action="store_true", help="recompute routes.json from ROUTE_SEQUENCES")
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args(argv)
    dem = basemap.load_dem()
    if dem is None:
        sys.exit("no terrain cache: run tools/osm_to_basemap.py first")
    graph, routes, pois, log, errors = run(basemap.OSM_CACHE, CONTENT, dem, args.update_routes)
    print("\n".join(log))
    print(f"graph: {len(graph['nodes'])} nodes, {len(graph['edges'])} edges, "
          f"{sum(e['length_m'] for e in graph['edges']) / 1000:.1f} km of trail")
    if errors:
        print("\n".join("ERROR " + e for e in errors))
        return 1
    if args.dry_run:
        return 0
    dump = lambda d: json.dumps(d, indent=2, ensure_ascii=False) + "\n"
    (CONTENT / "trail_graph.json").write_text(dump(graph), encoding="utf-8")
    if routes:
        (CONTENT / "routes.json").write_text(dump(routes), encoding="utf-8")
        (CONTENT / "pois.json").write_text(dump(pois), encoding="utf-8")
    GEOJSON.write_text(json.dumps({"type": "FeatureCollection", "features": [
        {"type": "Feature", "properties": {"from": e["from"], "to": e["to"], "kind": e["kind"]},
         "geometry": {"type": "LineString", "coordinates": [[ln, la] for la, ln in e["geometry"]]}}
        for e in graph["edges"]]}), encoding="utf-8")
    print("wrote trail_graph.json" + (", routes.json, pois.json" if routes else ""))
    return 0


if __name__ == "__main__":
    sys.exit(main())
