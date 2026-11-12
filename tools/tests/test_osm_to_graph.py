"""Tests for tools/osm_to_graph.py on a tiny synthetic OSM extract (no network)."""

import json
import math
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(ROOT / "tools"))

import osm_to_graph as o2g  # noqa: E402

LAT0, LNG0 = -6.85, 107.63
DLAT = 1 / 111320.0
DLNG = 1 / (111320.0 * math.cos(math.radians(LAT0)))


def pt(x_m, y_m):
    return (LAT0 + y_m * DLAT, LNG0 + x_m * DLNG)


def way(wid, hw, nodes):
    """nodes: list of (osm node id, x_m, y_m)."""
    return {"type": "way", "id": wid, "tags": {"highway": hw}, "nodes": [n for n, _, _ in nodes],
            "geometry": [dict(zip(("lat", "lon"), pt(x, y))) for _, x, y in nodes]}


class FlatDem:
    """Terrain rising 1 m per 10 m northwards."""

    def at(self, lat, lng):
        return 900 + (lat - LAT0) / DLAT / 10


class OsmToGraphTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp = Path(tempfile.mkdtemp())
        square = [pt(-300, -300), pt(300, -300), pt(300, 300), pt(-300, 300), pt(-300, -300)]
        boundary = {"type": "relation", "id": 1, "tags": {"boundary": "protected_area"},
                    "members": [{"type": "way", "role": "outer",
                                 "geometry": [{"lat": a, "lon": b} for a, b in square]}]}
        elements = [
            boundary,
            # main trail south → north with a junction at node 2 (0, 100)
            way(10, "path", [(1, 0, 0), (2, 0, 100), (3, 0, 200)]),
            # branch east from the junction
            way(11, "footway", [(2, 0, 100), (4, 80, 100), (5, 160, 100)]),
            # short stub (dead end, 10 m): pruned
            way(12, "path", [(3, 0, 200), (6, 10, 200)]),
            # disconnected path far away: dropped
            way(13, "path", [(7, 250, -250), (8, 260, -250)]),
            # road outside the boundary + 50 m: ignored
            way(14, "residential", [(9, 1000, 0), (20, 1100, 0)]),
        ]
        cls.osm = cls.tmp / "osm.json"
        cls.osm.write_text(json.dumps({"elements": elements}), encoding="utf-8")
        content = cls.tmp / "content"
        content.mkdir()

        def poi(pid, x, y):
            la, ln = pt(x, y)
            return {"id": pid, "name": pid, "lat": la, "lng": ln, "visit_minutes": 5}

        (content / "pois.json").write_text(json.dumps({"pois": [
            poi("P01", 0, -5), poi("P02", -5, 200), poi("P03", 160, 130)]}), encoding="utf-8")
        la, ln = pt(78, 100)
        (content / "facilities.json").write_text(json.dumps({"facilities": [
            {"id": "FS01", "lat": la, "lng": ln}]}), encoding="utf-8")
        (content / "park.json").write_text(json.dumps({"gate_poi": "P01", "params": {
            "walk_speed_m_per_min": 50, "ascent_min_per_10m": 1}}), encoding="utf-8")
        (content / "routes.json").write_text(json.dumps({"routes": [{"id": "santai"}]}), encoding="utf-8")
        cls.content = content
        o2g.ROUTE_SEQUENCES = {"santai": ["P01", "P02", "P03", "P01"]}
        cls.graph, cls.routes, cls.pois, cls.log, cls.errors = o2g.run(cls.osm, content, FlatDem(), True)

    def test_no_errors(self):
        self.assertEqual(self.errors, [])

    def test_items_become_nodes_on_the_trail(self):
        nodes = {n["id"]: n for n in self.graph["nodes"]}
        for nid in ("N_P01", "N_P02", "N_P03", "N_FS01"):
            self.assertIn(nid, nodes)
        self.assertEqual(nodes["N_P02"]["ref"], "P02")
        # P03 is 30 m off the branch end → attached with a warning
        self.assertTrue(any("P03" in m and "WARN" in m for m in self.log), self.log)

    def test_disconnected_and_outside_ways_are_dropped(self):
        far = {round(c, 4) for e in self.graph["edges"] for p in e["geometry"] for c in p}
        self.assertNotIn(round(pt(250, -250)[1], 4), far)
        self.assertNotIn(round(pt(1000, 0)[1], 4), far)

    def test_short_dead_end_stub_is_pruned(self):
        ends = [p for e in self.graph["edges"] for p in (e["geometry"][0], e["geometry"][-1])]
        stub = pt(10, 200)
        self.assertFalse(any(abs(a - stub[0]) < 1e-7 and abs(b - stub[1]) < 1e-7 for a, b in ends))

    def test_lengths_and_climb(self):
        total = sum(e["length_m"] for e in self.graph["edges"])
        self.assertAlmostEqual(total, 200 + 160, delta=3)
        north = next(e for e in self.graph["edges"] if e["to"] == "N_P02" or e["from"] == "N_P02")
        up = north["ascent_m"] if north["to"] == "N_P02" else north["descent_m"]
        self.assertGreater(up, 0)

    def test_route_is_recomputed_and_membership_written(self):
        r = self.routes["routes"][0]
        self.assertEqual(r["node_path"][0], "N_P01")
        self.assertEqual(r["node_path"][-1], "N_P01")
        self.assertIn("N_P02", r["node_path"])
        self.assertAlmostEqual(r["distance_m"], 2 * (200 + 160), delta=12)
        self.assertEqual({p["id"]: p["routes"] for p in self.pois["pois"]}["P02"], ["santai"])


if __name__ == "__main__":
    unittest.main()
