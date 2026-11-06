"""Tests for tools/gpx_to_graph.py, on a synthetic survey walk generated from the dummy graph.

    python -m unittest discover -s tools/tests -v
"""

import heapq
import json
import math
import random
import shutil
import sys
import tempfile
import unittest
from datetime import datetime, timedelta, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))

import gpx_to_graph as g2g  # noqa: E402

CONTENT = ROOT / "assets" / "content"
EARTH_R = 6371000.0


def haversine(a, b):
    la1, lo1, la2, lo2 = map(math.radians, (a[0], a[1], b[0], b[1]))
    h = math.sin((la2 - la1) / 2) ** 2 + math.cos(la1) * math.cos(la2) * math.sin((lo2 - lo1) / 2) ** 2
    return 2 * EARTH_R * math.asin(math.sqrt(h))


def shortest(adj, a, b):
    best, pq = {a: 0.0}, [(0.0, a)]
    while pq:
        d, u = heapq.heappop(pq)
        if u == b:
            return d
        if d > best[u]:
            continue
        for v, w in adj.get(u, ()):
            if d + w < best.get(v, math.inf):
                best[v] = d + w
                heapq.heappush(pq, (d + w, v))
    return math.inf


def adjacency(graph):
    adj = {}
    for e in graph["edges"]:
        length = sum(haversine(p, q) for p, q in zip(e["geometry"], e["geometry"][1:]))
        adj.setdefault(e["from"], []).append((e["to"], length))
        adj.setdefault(e["to"], []).append((e["from"], length))
    return adj


def synthetic_walk(graph, skip_edges=frozenset(), seed=7, noise_m=2.0):
    """One continuous track: depth-first, every edge walked out and back, 1.2 m per second."""
    rnd = random.Random(seed)
    nodes = {n["id"]: n for n in graph["nodes"]}
    out = {}
    for i, e in enumerate(graph["edges"]):
        if i in skip_edges:
            continue
        out.setdefault(e["from"], []).append((i, e, False))
        out.setdefault(e["to"], []).append((i, e, True))
    lat0 = nodes["N_P01"]["lat"]
    dlat = noise_m / EARTH_R * 180 / math.pi
    dlng = dlat / math.cos(math.radians(lat0))
    pts, walked, seen = [], set(), set()

    def walk(geom, ele_a, ele_b):
        total = sum(haversine(p, q) for p, q in zip(geom, geom[1:]))
        done = 0.0
        for p, q in zip(geom, geom[1:]):
            seg = haversine(p, q)
            n = max(1, int(seg / 1.2))
            for k in range(n):
                t = k / n
                frac = (done + seg * t) / total if total else 0
                pts.append(
                    (
                        p[0] + (q[0] - p[0]) * t + rnd.gauss(0, 1) * dlat,
                        p[1] + (q[1] - p[1]) * t + rnd.gauss(0, 1) * dlng,
                        ele_a + (ele_b - ele_a) * frac + rnd.gauss(0, 0.7),
                    )
                )
            done += seg

    def dfs(nid):
        seen.add(nid)
        for i, e, reverse in out.get(nid, []):
            if i in walked:
                continue
            walked.add(i)
            geom = list(reversed(e["geometry"])) if reverse else e["geometry"]
            other = e["from"] if reverse else e["to"]
            walk(geom, nodes[nid]["ele"], nodes[other]["ele"])
            if other not in seen:
                dfs(other)
            walk(list(reversed(geom)), nodes[other]["ele"], nodes[nid]["ele"])

    dfs("N_P01")
    last = nodes["N_P01"]
    pts.append((last["lat"], last["lng"], last["ele"]))
    return pts


def write_gpx(path, pts, waypoints=()):
    t0 = datetime(2026, 11, 7, 8, 0, tzinfo=timezone.utc)
    rows = [
        f'<trkpt lat="{la:.7f}" lon="{lo:.7f}"><ele>{el:.1f}</ele>'
        f"<time>{(t0 + timedelta(seconds=i)).isoformat().replace('+00:00', 'Z')}</time></trkpt>"
        for i, (la, lo, el) in enumerate(pts)
    ]
    wpts = [f'<wpt lat="{la}" lon="{lo}"><name>{n}</name></wpt>' for n, la, lo in waypoints]
    path.write_text(
        '<?xml version="1.0"?><gpx version="1.1" creator="test" xmlns="http://www.topografix.com/GPX/1/1">'
        + "".join(wpts)
        + "<trk><trkseg>"
        + "".join(rows)
        + "</trkseg></trk></gpx>",
        encoding="utf-8",
    )


class GpxToGraphTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.dummy = json.loads((CONTENT / "trail_graph.json").read_text(encoding="utf-8"))
        cls.pois = json.loads((CONTENT / "pois.json").read_text(encoding="utf-8"))["pois"]
        cls.facilities = json.loads((CONTENT / "facilities.json").read_text(encoding="utf-8"))["facilities"]
        cls.tmp = Path(tempfile.mkdtemp())
        junctions = [(n["id"], n["lat"], n["lng"]) for n in cls.dummy["nodes"] if n["id"].startswith("J")]
        cls.gpx = cls.tmp / "survey.gpx"
        write_gpx(cls.gpx, synthetic_walk(cls.dummy), junctions)
        cls.res = g2g.run([cls.gpx], CONTENT, g2g.Params(), update_routes=True)

    @classmethod
    def tearDownClass(cls):
        shutil.rmtree(cls.tmp, ignore_errors=True)

    def test_no_errors(self):
        self.assertEqual(self.res.report.errors, [])

    def test_every_poi_and_facility_has_its_node(self):
        ids = {n["id"]: n for n in self.res.graph_json["nodes"]}
        for item in self.pois + self.facilities:
            self.assertIn(item["graph_node"], ids, item["id"])
            self.assertEqual(ids[item["graph_node"]]["ref"], item["id"])

    def test_walking_distances_match_the_original_network(self):
        want, got = adjacency(self.dummy), adjacency(self.res.graph_json)
        nodes = [p["graph_node"] for p in self.pois]
        for i, a in enumerate(nodes):
            for b in nodes[i + 1 :]:
                w, g = shortest(want, a, b), shortest(got, a, b)
                self.assertLess(abs(w - g), max(15.0, 0.05 * w), f"{a}→{b}: want {w:.0f} m, got {g:.0f} m")

    def test_total_length_is_not_inflated_by_gps_jitter(self):
        want = sum(w for edges in adjacency(self.dummy).values() for _, w in edges) / 2
        got = sum(e["length_m"] for e in self.res.graph_json["edges"])
        self.assertLess(abs(got - want) / want, 0.03, f"want {want:.0f} m, got {got:.0f} m")

    def test_robust_across_noise_patterns(self):
        # One seed passing can be luck (a missed junction once hid behind seed 7): try several.
        want = adjacency(self.dummy)
        nodes = [p["graph_node"] for p in self.pois]
        for seed in range(1, 6):
            gpx = self.tmp / f"seed{seed}.gpx"
            write_gpx(gpx, synthetic_walk(self.dummy, seed=seed))
            res = g2g.run([gpx], CONTENT, g2g.Params())
            self.assertEqual(res.report.errors, [], f"seed {seed}")
            got = adjacency(res.graph_json)
            for i, a in enumerate(nodes):
                for b in nodes[i + 1 :]:
                    w, g = shortest(want, a, b), shortest(got, a, b)
                    self.assertLess(abs(w - g), max(20.0, 0.05 * w), f"seed {seed} {a}→{b}: {w:.0f} vs {g:.0f} m")

    def test_junction_count_is_close_to_the_original(self):
        want = sum(1 for n in self.dummy["nodes"] if n["ref"] is None)
        got = sum(1 for n in self.res.graph_json["nodes"] if n["ref"] is None)
        self.assertLessEqual(abs(want - got), 2, f"want ~{want} junctions, got {got}")

    def test_junction_waypoints_name_their_junction(self):
        names = {n["id"] for n in self.res.graph_json["nodes"] if n["ref"] is None}
        self.assertTrue(names & {"J01", "J02", "J03"})

    def test_edges_are_valid(self):
        ids = {n["id"] for n in self.res.graph_json["nodes"]}
        for e in self.res.graph_json["edges"]:
            self.assertIn(e["from"], ids)
            self.assertIn(e["to"], ids)
            self.assertNotEqual(e["from"], e["to"])
            self.assertGreater(e["length_m"], 0)
            self.assertGreaterEqual(len(e["geometry"]), 2)

    def test_elevation_gain_is_measured(self):
        self.assertGreater(sum(e["ascent_m"] + e["descent_m"] for e in self.res.graph_json["edges"]), 0)

    def test_routes_follow_the_new_graph(self):
        pairs = {(e["from"], e["to"]) for e in self.res.graph_json["edges"]}
        pairs |= {(b, a) for a, b in pairs}
        node_of = {p["id"]: p["graph_node"] for p in self.pois}
        for r in self.res.routes_json["routes"]:
            path = r["node_path"]
            self.assertEqual(path[0], node_of[r["poi_sequence"][0]], r["id"])
            self.assertEqual(path[-1], node_of[r["poi_sequence"][-1]], r["id"])
            for a, b in zip(path, path[1:]):
                self.assertIn((a, b), pairs, f"{r['id']}: {a}→{b} is not an edge")

    def test_poi_far_from_any_trail_is_flagged(self):
        content = self.tmp / "content_far"
        shutil.copytree(CONTENT, content)
        pois_f = json.loads((content / "pois.json").read_text(encoding="utf-8"))
        moved = pois_f["pois"][3]
        moved["lng"] += 40 / (EARTH_R * math.pi / 180 * math.cos(math.radians(moved["lat"])))  # ~40 m east
        (content / "pois.json").write_text(json.dumps(pois_f), encoding="utf-8")
        res = g2g.run([self.gpx], content, g2g.Params())
        self.assertTrue(any(moved["id"] in w for w in res.report.warnings + res.report.errors), res.report.warnings)

    def test_missing_trail_segment_is_reported(self):
        leaf_edges = {}
        degree = {}
        for e in self.dummy["edges"]:
            degree[e["from"]] = degree.get(e["from"], 0) + 1
            degree[e["to"]] = degree.get(e["to"], 0) + 1
        for i, e in enumerate(self.dummy["edges"]):
            for end in (e["from"], e["to"]):
                if degree[end] == 1 and end.startswith("N_P") and end != "N_P01":
                    leaf_edges[i] = end
        self.assertTrue(leaf_edges, "dummy graph has no leaf POI to test with")
        i, leaf = next(iter(leaf_edges.items()))
        gpx = self.tmp / "missing.gpx"
        write_gpx(gpx, synthetic_walk(self.dummy, skip_edges={i}))
        res = g2g.run([gpx], CONTENT, g2g.Params())
        poi_id = leaf.removeprefix("N_")
        self.assertTrue(
            any(poi_id in m for m in res.report.warnings + res.report.errors),
            f"{poi_id} not reported: {res.report.warnings + res.report.errors}",
        )

    def test_cli_writes_graph_and_preview(self):
        out, preview = self.tmp / "graph.json", self.tmp / "preview.geojson"
        code = g2g.main([str(self.gpx), "--out", str(out), "--geojson", str(preview)])
        self.assertEqual(code, 0)
        graph = json.loads(out.read_text(encoding="utf-8"))
        self.assertFalse(graph["dummy"])
        self.assertEqual(json.loads(preview.read_text(encoding="utf-8"))["type"], "FeatureCollection")


if __name__ == "__main__":
    unittest.main()
