"""Build assets/content/trail_graph.json from survey GPX tracks (T13, PB12; IMPLEMENTATION_PLAN F06).

    python tools/gpx_to_graph.py survey/raw/2026-11-07/            # every *.gpx in the folder
    python tools/gpx_to_graph.py a.gpx b.gpx --update-routes       # also rewrite routes.json node paths

Inputs: GPX tracks (one long track or one file per segment, both fine; junction waypoints named
J01, J02, … are used as node names when they sit on a detected junction) plus the POI/facility
coordinates already in assets/content/pois.json and facilities.json.

Outputs:
- assets/content/trail_graph.json (only when there are no errors, unless --force)
- a GeoJSON preview (always) — drag it onto https://geojson.io to eyeball the result
- a report: POIs more than 25 m from a trail, unreachable POIs, gaps, missing elevation

How it works (all maths in a local metric plane, standard library only):
1. Clean each track: drop points with HDOP > 5 or jumps > 10 m faster than 3 m/s, smooth
   (moving average), resample every 2 m, smooth again.
2. Walk the track; a stretch more than 8 m from every trail seen so far is NEW trail, a stretch
   within 8 m is a re-walk of a known trail and is dropped. The points where the walk leaves or
   joins a known trail become junctions. (Out-and-back walks, loops and repeated segments work.)
3. Split trails at junctions and at the point nearest each POI/facility; cluster end points into
   nodes; collapse junction clusters closer than 12 m; drop GPS spurs shorter than 15 m; merge
   pass-through nodes.
4. Edge length from the smoothed geometry, ascent/descent with a 2 m noise gate, geometry
   simplified (Douglas–Peucker 3 m).
5. Every POI/facility node must be reachable from the gate (park.json gate_poi), else error.
"""

from __future__ import annotations

import argparse
import heapq
import json
import math
import sys
import xml.etree.ElementTree as ET
from collections import defaultdict, deque
from dataclasses import dataclass, field
from datetime import datetime
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
EARTH_R = 6371000.0


@dataclass
class Params:
    max_hdop: float = 5.0
    max_speed_mps: float = 3.0
    jump_m: float = 10.0
    step_m: float = 2.0  # resample spacing
    merge_m: float = 8.0  # closer than this to a known trail = same trail
    min_run_m: float = 15.0  # new stretches / spurs shorter than this are GPS noise
    node_merge_m: float = 3.0
    collapse_m: float = 12.0  # junction points closer than this along a trail are one junction
    simplify_m: float = 3.0
    ele_gate_m: float = 2.0
    poi_warn_m: float = 25.0  # PLAN F06 step 5
    poi_error_m: float = 100.0  # almost certainly a wrong coordinate
    gap_warn_m: float = 40.0
    waypoint_snap_m: float = 10.0


# ---------------------------------------------------------------------------------------------
# geometry (points are tuples (x, y, ele|None) in metres)
# ---------------------------------------------------------------------------------------------


class Projection:
    """Local equirectangular projection; accurate to centimetres over a few km."""

    def __init__(self, lat0: float, lng0: float):
        self.lat0, self.lng0 = lat0, lng0
        self.ky = EARTH_R * math.pi / 180
        self.kx = self.ky * math.cos(math.radians(lat0))

    def xy(self, lat: float, lng: float) -> tuple[float, float]:
        return (lng - self.lng0) * self.kx, (lat - self.lat0) * self.ky

    def latlng(self, x: float, y: float) -> tuple[float, float]:
        return self.lat0 + y / self.ky, self.lng0 + x / self.kx


def dist(a, b) -> float:
    return math.hypot(a[0] - b[0], a[1] - b[1])


def lerp(a, b, t: float):
    ea, eb = a[2], b[2]
    ele = None if ea is None or eb is None else ea + (eb - ea) * t
    return (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t, ele)


def project(p, a, b):
    """Distance from p to segment ab, parameter t in [0,1], and the projected point."""
    dx, dy = b[0] - a[0], b[1] - a[1]
    L2 = dx * dx + dy * dy
    t = 0.0 if L2 == 0 else max(0.0, min(1.0, ((p[0] - a[0]) * dx + (p[1] - a[1]) * dy) / L2))
    q = lerp(a, b, t)
    return dist(p, q), t, q


def path_len(pts) -> float:
    return sum(dist(a, b) for a, b in zip(pts, pts[1:]))


def resample(pts, step: float):
    if len(pts) < 2:
        return list(pts)
    out, carry = [pts[0]], 0.0
    for a, b in zip(pts, pts[1:]):
        seg = dist(a, b)
        if seg == 0:
            continue
        pos = step - carry
        while pos <= seg:
            out.append(lerp(a, b, pos / seg))
            pos += step
        carry = seg - (pos - step)
    if dist(out[-1], pts[-1]) > step / 4:
        out.append(pts[-1])
    return out


def smooth(pts, window_xy: int = 3, window_ele: int = 5):
    if len(pts) < 3:
        return list(pts)
    out = []
    for i, p in enumerate(pts):
        if i == 0 or i == len(pts) - 1:
            out.append(p)
            continue
        h = window_xy // 2
        w = pts[max(0, i - h) : i + h + 1]
        x = sum(q[0] for q in w) / len(w)
        y = sum(q[1] for q in w) / len(w)
        he = window_ele // 2
        eles = [q[2] for q in pts[max(0, i - he) : i + he + 1] if q[2] is not None]
        out.append((x, y, sum(eles) / len(eles) if eles else None))
    return out


def simplify(pts, tol: float):
    if len(pts) < 3:
        return list(pts)
    keep = [False] * len(pts)
    keep[0] = keep[-1] = True
    stack = [(0, len(pts) - 1)]
    while stack:
        i, j = stack.pop()
        dmax, k = 0.0, -1
        for m in range(i + 1, j):
            d = project(pts[m], pts[i], pts[j])[0]
            if d > dmax:
                dmax, k = d, m
        if dmax > tol:
            keep[k] = True
            stack += [(i, k), (k, j)]
    return [p for p, kp in zip(pts, keep) if kp]


def climb(pts, gate: float) -> tuple[float, float]:
    """Ascent/descent with a noise gate (phone GPS elevation jitters by several metres)."""
    eles = [p[2] for p in pts if p[2] is not None]
    if len(eles) < 2:
        return 0.0, 0.0
    up = down = 0.0
    ref = eles[0]
    for e in eles[1:]:
        if e - ref >= gate:
            up, ref = up + e - ref, e
        elif ref - e >= gate:
            down, ref = down + ref - e, e
    return up, down


class SegmentIndex:
    """Grid index over polyline segments (polylines are never mutated once added)."""

    def __init__(self, cell: float):
        self.cell = cell
        self.grid: dict[tuple[int, int], list[tuple[int, int]]] = defaultdict(list)
        self.polys: list[list] = []

    def add(self, pts) -> int:
        pid = len(self.polys)
        self.polys.append(pts)
        c = self.cell
        for i, (a, b) in enumerate(zip(pts, pts[1:])):
            for cx in range(int(math.floor(min(a[0], b[0]) / c)), int(math.floor(max(a[0], b[0]) / c)) + 1):
                for cy in range(int(math.floor(min(a[1], b[1]) / c)), int(math.floor(max(a[1], b[1]) / c)) + 1):
                    self.grid[(cx, cy)].append((pid, i))
        return pid

    def hits(self, p, maxd: float):
        """Best (d, pid, seg, t, q) per polyline within maxd."""
        c = self.cell
        r = int(maxd // c) + 1
        cx, cy = int(math.floor(p[0] / c)), int(math.floor(p[1] / c))
        best: dict[int, tuple] = {}
        seen = set()
        for gx in range(cx - r, cx + r + 1):
            for gy in range(cy - r, cy + r + 1):
                for key in self.grid.get((gx, gy), ()):
                    if key in seen:
                        continue
                    seen.add(key)
                    pid, i = key
                    poly = self.polys[pid]
                    d, t, q = project(p, poly[i], poly[i + 1])
                    if d <= maxd and (pid not in best or d < best[pid][0]):
                        best[pid] = (d, pid, i, t, q)
        return list(best.values())

    def nearest(self, p, maxd: float):
        hs = self.hits(p, maxd)
        return min(hs, key=lambda h: h[0]) if hs else None


class PointIndex:
    """Grid over the points of the run being built, for out-and-back / loop detection."""

    def __init__(self, cell: float):
        self.cell = cell
        self.grid: dict[tuple[int, int], list[int]] = defaultdict(list)

    def add(self, i: int, p):
        self.grid[(int(math.floor(p[0] / self.cell)), int(math.floor(p[1] / self.cell)))].append(i)

    def nearest(self, p, pts, maxd: float, below: int):
        c = self.cell
        r = int(maxd // c) + 1
        cx, cy = int(math.floor(p[0] / c)), int(math.floor(p[1] / c))
        best = None
        for gx in range(cx - r, cx + r + 1):
            for gy in range(cy - r, cy + r + 1):
                for i in self.grid.get((gx, gy), ()):
                    if i >= below:
                        continue
                    d = dist(p, pts[i])
                    if d <= maxd and (best is None or d < best[0]):
                        best = (d, i)
        return best


# ---------------------------------------------------------------------------------------------
# GPX parsing and cleaning
# ---------------------------------------------------------------------------------------------


@dataclass
class RawPoint:
    lat: float
    lng: float
    ele: float | None
    hdop: float | None
    time: datetime | None


@dataclass
class GpxData:
    tracks: list[list[RawPoint]] = field(default_factory=list)
    waypoints: list[tuple[str, float, float]] = field(default_factory=list)
    files: list[str] = field(default_factory=list)


def _num(el) -> float | None:
    try:
        return float(el.text) if el is not None and el.text and el.text.strip() else None
    except ValueError:
        return None


def _time(el) -> datetime | None:
    if el is None or not el.text:
        return None
    try:
        return datetime.fromisoformat(el.text.strip().replace("Z", "+00:00"))
    except ValueError:
        return None


def read_gpx(paths: list[Path]) -> GpxData:
    data = GpxData()
    for path in paths:
        root = ET.parse(path).getroot()
        ns = root.tag[: root.tag.index("}") + 1] if root.tag.startswith("{") else ""
        data.files.append(path.name)
        for seg in root.iter(f"{ns}trkseg"):
            pts = [
                RawPoint(
                    float(pt.get("lat")),
                    float(pt.get("lon")),
                    _num(pt.find(f"{ns}ele")),
                    _num(pt.find(f"{ns}hdop")),
                    _time(pt.find(f"{ns}time")),
                )
                for pt in seg.iter(f"{ns}trkpt")
            ]
            if len(pts) >= 2:
                data.tracks.append(pts)
        for w in root.iter(f"{ns}wpt"):
            data.waypoints.append(((w.findtext(f"{ns}name") or "").strip(), float(w.get("lat")), float(w.get("lon"))))
    return data


def clean_track(raw: list[RawPoint], proj: Projection, prm: Params, report: "Report", name: str):
    kept: list[RawPoint] = []
    dropped_hdop = dropped_speed = 0
    for p in raw:
        if p.hdop is not None and p.hdop > prm.max_hdop:
            dropped_hdop += 1
            continue
        if kept and p.time and kept[-1].time:
            dt = (p.time - kept[-1].time).total_seconds()
            d = dist(proj.xy(p.lat, p.lng), proj.xy(kept[-1].lat, kept[-1].lng))
            # A jump must be both fast AND long: at 1 s logging, normal 2–3 m jitter looks "fast".
            if dt > 0 and d > prm.jump_m and d / dt > prm.max_speed_mps:
                dropped_speed += 1
                continue
        kept.append(p)
    if dropped_hdop or dropped_speed:
        report.info(f"{name}: dropped {dropped_hdop} high-HDOP and {dropped_speed} speed-outlier points")
    pts = [(*proj.xy(p.lat, p.lng), p.ele) for p in kept]
    for a, b in zip(pts, pts[1:]):
        if dist(a, b) > prm.gap_warn_m:
            lat, lng = proj.latlng(*a[:2])
            report.warn(f"{name}: {dist(a, b):.0f} m gap without points near {lat:.6f},{lng:.6f} (GPS lost?)")
    pts = _fill_elevation(pts)
    # Smooth before AND after resampling: GPS jitter otherwise zig-zags the path and inflates
    # lengths (and so every ETA) by ~17%; 5+5 brings it to ~0% without cutting corners.
    pts = resample(smooth(pts, 5, 5), prm.step_m)
    return smooth(pts, 5, 5)


def _fill_elevation(pts):
    known = [i for i, p in enumerate(pts) if p[2] is not None]
    if not known or len(known) == len(pts):
        return pts
    out = list(pts)
    for i, p in enumerate(pts):
        if p[2] is None:
            prev = max((k for k in known if k < i), default=None)
            nxt = min((k for k in known if k > i), default=None)
            src = prev if nxt is None else nxt if prev is None else (prev if i - prev <= nxt - i else nxt)
            out[i] = (p[0], p[1], pts[src][2])
    return out


# ---------------------------------------------------------------------------------------------
# graph building
# ---------------------------------------------------------------------------------------------


class Report:
    def __init__(self):
        self.errors: list[str] = []
        self.warnings: list[str] = []
        self.infos: list[str] = []

    def error(self, m):
        self.errors.append(m)

    def warn(self, m):
        self.warnings.append(m)

    def info(self, m):
        self.infos.append(m)


def extract_trails(tracks, prm: Params) -> tuple[SegmentIndex, list]:
    """Step 2: keep only new stretches; return the trail polylines and the junction points.

    States per track: NEW (walking a trail not seen before), JOINING (came within merge_m of a
    known trail; wait until within anchor_m so a shallow-angle join is placed where the paths
    actually meet), COVERED (re-walking a known trail; on leaving, the junction is set back to the
    last point that was within anchor_m, again so shallow-angle splits land in the right place).
    """
    index = SegmentIndex(cell=max(prm.merge_m * 2, 10.0))
    junctions: list = []
    exit_m = prm.merge_m * 1.5
    anchor_m = prm.merge_m / 2
    tail = math.ceil(3 * prm.merge_m / prm.step_m)  # own recent points never count as "known"
    turnaround_m = 4 * prm.merge_m  # a self-loop shorter than this is walking back, not a loop

    for pts in tracks:
        st = {"mode": "new", "run": [], "anchored": False}
        run_idx = PointIndex(cell=prm.merge_m)
        joinbuf: list = []
        best = (math.inf, 0, None)  # JOINING: closest approach (distance, joinbuf index, projection)
        recent: list = []  # COVERED: (point, distance, projection), newest last

        def reset_run(points, anchored):
            nonlocal run_idx
            st["run"], st["anchored"] = list(points), anchored
            run_idx = PointIndex(cell=prm.merge_m)
            for i, q in enumerate(st["run"]):
                run_idx.add(i, q)

        def append(q):
            run_idx.add(len(st["run"]), q)
            st["run"].append(q)

        def flush(end_point, end_anchored):
            pts_ = st["run"] + ([end_point] if end_point is not None else [])
            length = path_len(pts_)
            noise = st["anchored"] and end_anchored and length < prm.min_run_m
            if len(pts_) >= 2 and length > prm.step_m and not noise:
                index.add(pts_)
                if st["anchored"]:
                    junctions.append(pts_[0])
                if end_anchored:
                    junctions.append(pts_[-1])
            reset_run([], False)

        def nearest_known(q, maxd):
            """(distance, join point, is_self, self_index) to known trails or own older points."""
            hit = index.nearest(q, maxd)
            run = st["run"]
            sh = run_idx.nearest(q, run, maxd, below=len(run) - tail) if len(run) > tail else None
            if sh is not None and (hit is None or sh[0] < hit[0]):
                return sh[0], run[sh[1]], True, sh[1]
            if hit is not None:
                return hit[0], hit[4], False, -1
            return None

        def enter_covered():
            st["mode"] = "covered"
            recent.clear()

        def finish_join(i, proj_point):
            nonlocal joinbuf
            for q in joinbuf[:i]:
                append(q)
            joinbuf = []
            flush(proj_point, True)
            enter_covered()

        for p in pts:
            mode = st["mode"]
            if mode == "covered":
                hit = index.nearest(p, exit_m)
                if hit is not None:
                    recent.append((p, hit[0], hit[4]))
                    if len(recent) > 4 * tail:
                        del recent[0]
                    continue
                # leaving a known trail: the split is at the last point still close to it
                k = max((i for i, r in enumerate(recent) if r[1] <= anchor_m), default=0)
                start = recent[k][2] if recent else p
                reset_run([start] + [r[0] for r in recent[k + 1 :]] + [p], True)
                st["mode"] = "new"
                continue

            if mode == "joining":
                # distances to OTHER trails only; coming back along its own path = turnaround
                hit = index.nearest(p, exit_m)
                joinbuf.append(p)
                if hit is not None and hit[0] < best[0]:
                    best = (hit[0], len(joinbuf) - 1, hit[4])
                entry = st["run"][-1] if st["run"] else joinbuf[0]
                turned = dist(p, entry) < dist(joinbuf[best[1]], entry) - anchor_m
                if hit is not None and hit[0] <= anchor_m:
                    finish_join(len(joinbuf) - 1, hit[4])
                elif turned or len(joinbuf) > 2 * tail:
                    finish_join(best[1], best[2])
                elif hit is None:  # false alarm: it was only passing close by
                    for q in joinbuf:
                        append(q)
                    joinbuf.clear()
                    st["mode"] = "new"
                continue

            # mode == "new"
            near = nearest_known(p, prm.merge_m)
            if near is None:
                append(p)
                continue
            d, join, is_self, k = near
            run = st["run"]
            if is_self and path_len(run[k:]) + d < turnaround_m:
                # walked to a dead end (cave, viewpoint, facility) and turned back: cut at the tip;
                # if the tip touches another trail, it is a junction there
                tip = max(range(k, len(run)), key=lambda j: dist(run[k], run[j]))
                st["run"] = run[: tip + 1]
                at = index.nearest(run[tip], exit_m)
                flush(at[4] if at else None, at is not None)
                enter_covered()
                continue
            if is_self:  # a real loop back onto its own path
                flush(join, True)
                enter_covered()
            elif d <= anchor_m:
                flush(join, True)
                enter_covered()
            else:
                st["mode"] = "joining"
                joinbuf = [p]
                best = (d, 0, join)

        if st["mode"] == "joining":
            for q in joinbuf:
                append(q)
        if st["mode"] != "covered" and st["run"]:
            flush(None, False)
    return index, junctions


@dataclass
class Edge:
    u: int
    v: int
    pts: list


class Graph:
    def __init__(self):
        self.pos: dict[int, tuple] = {}
        self.edges: dict[int, Edge] = {}
        self.adj: dict[int, set[int]] = defaultdict(set)  # node -> edge ids
        self.poi: dict[int, str] = {}  # node -> item id (POI or facility)
        self._next_node = 0
        self._next_edge = 0

    def add_node(self, p) -> int:
        n = self._next_node
        self._next_node += 1
        self.pos[n] = p
        self.adj[n]
        return n

    def add_edge(self, u, v, pts) -> int:
        e = self._next_edge
        self._next_edge += 1
        pts = [self.pos[u], *pts[1:-1], self.pos[v]]
        self.edges[e] = Edge(u, v, pts)
        self.adj[u].add(e)
        self.adj[v].add(e)
        return e

    def remove_edge(self, e):
        ed = self.edges.pop(e)
        self.adj[ed.u].discard(e)
        self.adj[ed.v].discard(e)

    def remove_node(self, n):
        for e in list(self.adj[n]):
            self.remove_edge(e)
        del self.adj[n]
        del self.pos[n]
        self.poi.pop(n, None)

    def other(self, e, n) -> int:
        ed = self.edges[e]
        return ed.v if ed.u == n else ed.u

    def degree(self, n) -> int:
        return sum(2 if self.edges[e].u == self.edges[e].v else 1 for e in self.adj[n])

    def oriented(self, e, start) -> list:
        ed = self.edges[e]
        return ed.pts if ed.u == start else list(reversed(ed.pts))

    def length(self, e) -> float:
        return path_len(self.edges[e].pts)


def build_graph(trails: SegmentIndex, cuts: list, prm: Params) -> tuple[Graph, list]:
    """Step 3a: split polylines at cut points, cluster end points into nodes."""
    per_poly: dict[int, list] = defaultdict(list)
    for c in cuts:
        for d, pid, i, t, q in trails.hits(c, prm.node_merge_m / 3):
            per_poly[pid].append((i, t, q))
    g = Graph()
    node_grid: dict[tuple[int, int], list[int]] = defaultdict(list)
    cell = prm.node_merge_m

    def node_at(p) -> int:
        cx, cy = int(math.floor(p[0] / cell)), int(math.floor(p[1] / cell))
        best = None
        for gx in (cx - 1, cx, cx + 1):
            for gy in (cy - 1, cy, cy + 1):
                for n in node_grid.get((gx, gy), ()):
                    d = dist(p, g.pos[n])
                    if d <= prm.node_merge_m and (best is None or d < best[0]):
                        best = (d, n)
        if best:
            return best[1]
        n = g.add_node(p)
        node_grid[(cx, cy)].append(n)
        return n

    for pid, poly in enumerate(trails.polys):
        cs = sorted(per_poly.get(pid, []), key=lambda c: (c[0], c[1]))
        piece = [poly[0]]
        seg = 0
        for i, t, q in cs:
            while seg < i:
                seg += 1
                piece.append(poly[seg])
            piece.append(q)
            if path_len(piece) > 0.5:
                g.add_edge(node_at(piece[0]), node_at(piece[-1]), piece)
                piece = [q]
            else:
                piece = [piece[0]]
        while seg < len(poly) - 1:
            seg += 1
            piece.append(poly[seg])
        if path_len(piece) > 0.5:
            g.add_edge(node_at(piece[0]), node_at(piece[-1]), piece)
    return g, [node_at(c) for c in cuts]


def merge_nodes(g: Graph, keep: int, gone: int):
    if keep not in g.poi:
        # two detections of one junction: the truth is most likely between them
        a, b = g.pos[keep], g.pos[gone]
        ele = a[2] if b[2] is None else b[2] if a[2] is None else (a[2] + b[2]) / 2
        g.pos[keep] = ((a[0] + b[0]) / 2, (a[1] + b[1]) / 2, ele)
        for e in list(g.adj[keep]):
            ed = g.edges[e]
            g.remove_edge(e)
            g.add_edge(ed.u, ed.v, ed.pts)  # re-anchors the geometry on the moved node
    for e in list(g.adj[gone]):
        ed = g.edges[e]
        u = keep if ed.u == gone else ed.u
        v = keep if ed.v == gone else ed.v
        g.remove_edge(e)
        if u == v and path_len(ed.pts) < 1.0:
            continue
        g.add_edge(u, v, ed.pts)
    g.remove_node(gone)


def tidy(g: Graph, prm: Params):
    """Step 3b: collapse junction clusters, drop spurs, merge pass-through nodes, split loops."""
    changed = True
    while changed:
        changed = False
        # tiny self-loops are turnaround noise
        for e in [e for e, ed in g.edges.items() if ed.u == ed.v and path_len(ed.pts) < prm.min_run_m]:
            g.remove_edge(e)
            changed = True
        # collapse short edges (several junction points detected around one real junction)
        for e in sorted(g.edges, key=g.length):
            if e not in g.edges:
                continue
            ed = g.edges[e]
            if ed.u == ed.v or g.length(e) >= prm.collapse_m:
                continue
            if ed.u in g.poi and ed.v in g.poi:
                continue
            if g.degree(ed.u) == 1 or g.degree(ed.v) == 1:
                continue  # that's a spur; handled below
            keep, gone = (ed.v, ed.u) if ed.v in g.poi else (ed.u, ed.v)
            g.remove_edge(e)
            merge_nodes(g, keep, gone)
            changed = True
        # spurs: short dead ends without a POI are GPS noise
        for n in list(g.pos):
            if n in g.pos and n not in g.poi and g.degree(n) == 1:
                (e,) = g.adj[n]
                if g.length(e) < prm.min_run_m:
                    g.remove_node(n)
                    changed = True
        # isolated nodes
        for n in list(g.pos):
            if not g.adj[n] and n not in g.poi:
                g.remove_node(n)
        # pass-through nodes
        for n in list(g.pos):
            if n not in g.pos or n in g.poi or g.degree(n) != 2 or len(g.adj[n]) != 2:
                continue
            e1, e2 = g.adj[n]
            a, b = g.other(e1, n), g.other(e2, n)
            if a == b:
                continue  # would become a self-loop
            pts = list(reversed(g.oriented(e1, n))) + g.oriented(e2, n)[1:]
            g.remove_node(n)
            g.add_edge(a, b, pts)
            changed = True
    # self-loops (a loop trail with one junction): split in the middle
    for e in [e for e, ed in g.edges.items() if ed.u == ed.v]:
        ed = g.edges[e]
        pts = ed.pts
        half = path_len(pts) / 2
        acc, k = 0.0, 1
        while k < len(pts) - 1 and acc + dist(pts[k - 1], pts[k]) < half:
            acc += dist(pts[k - 1], pts[k])
            k += 1
        mid = g.add_node(pts[k])
        g.remove_edge(e)
        g.add_edge(ed.u, mid, pts[: k + 1])
        g.add_edge(mid, ed.u, pts[k:])


def dijkstra(adj: dict, start: str, goal: str):
    dist_ = {start: 0.0}
    prev: dict[str, str] = {}
    pq = [(0.0, start)]
    while pq:
        d, u = heapq.heappop(pq)
        if u == goal:
            break
        if d > dist_[u]:
            continue
        for v, w in adj[u]:
            nd = d + w
            if nd < dist_.get(v, math.inf):
                dist_[v], prev[v] = nd, u
                heapq.heappush(pq, (nd, v))
    if goal not in dist_:
        return None
    path = [goal]
    while path[-1] != start:
        path.append(prev[path[-1]])
    return list(reversed(path))


# ---------------------------------------------------------------------------------------------
# main pipeline
# ---------------------------------------------------------------------------------------------


@dataclass
class Result:
    graph_json: dict
    geojson: dict
    report: Report
    routes_json: dict | None = None


def run(gpx_paths: list[Path], content_dir: Path, prm: Params, update_routes: bool = False) -> Result:
    report = Report()
    data = read_gpx(gpx_paths)
    pois = json.loads((content_dir / "pois.json").read_text(encoding="utf-8"))["pois"]
    facilities = json.loads((content_dir / "facilities.json").read_text(encoding="utf-8"))["facilities"]
    park = json.loads((content_dir / "park.json").read_text(encoding="utf-8"))
    items = [(p["id"], p.get("graph_node") or f"N_{p['id']}", p["lat"], p["lng"], "poi") for p in pois]
    items += [(f["id"], f.get("graph_node") or f"N_{f['id']}", f["lat"], f["lng"], "facility") for f in facilities]
    if not data.tracks:
        report.error("no GPX track points found")
        return Result({}, {"type": "FeatureCollection", "features": []}, report)

    all_pts = [p for t in data.tracks for p in t]
    proj = Projection(sum(p.lat for p in all_pts) / len(all_pts), sum(p.lng for p in all_pts) / len(all_pts))
    tracks = [clean_track(t, proj, prm, report, f"track {i + 1}") for i, t in enumerate(data.tracks)]
    if all(p[2] is None for t in tracks for p in t):
        report.warn("GPX has no elevation: ascent/descent are 0 and the slope ETA (D09) will be flat")

    trails, junctions = extract_trails(tracks, prm)
    if not trails.polys:
        report.error("no trail left after cleaning (track too short?)")
        return Result({}, {"type": "FeatureCollection", "features": []}, report)

    # waypoints named J.. snap onto the nearest trail as extra cut points
    wp_cuts = []
    for name, lat, lng in data.waypoints:
        if not name.upper().startswith("J"):
            continue  # other pins (e.g. POI readings P05_1) are notes, not trail cuts
        p = (*proj.xy(lat, lng), None)
        hit = trails.nearest(p, prm.merge_m * 2)
        if hit:
            wp_cuts.append(hit[4])

    # items attach at their nearest trail point
    attach = []
    for iid, node_name, lat, lng, kind in items:
        p = (*proj.xy(lat, lng), None)
        hit = _nearest_any(trails, p)
        d = hit[0]
        if d > prm.poi_error_m:
            report.error(f"{iid}: {d:.0f} m from the nearest trail — wrong coordinate or a trail not recorded")
        elif d > prm.poi_warn_m:
            report.warn(f"{iid}: {d:.0f} m from the nearest trail (> {prm.poi_warn_m:.0f} m) — check on site")
        attach.append((iid, node_name, kind, p, hit[4], d))

    cuts = junctions + wp_cuts + [a[4] for a in attach]
    g, cut_nodes = build_graph(trails, cuts, prm)
    item_nodes = cut_nodes[len(junctions) + len(wp_cuts) :]
    for (iid, node_name, kind, p, q, d), n in zip(attach, item_nodes):
        if n in g.poi:
            twin = g.add_node(g.pos[n])
            g.add_edge(n, twin, [g.pos[n], g.pos[n]])
            report.warn(f"{iid} and {g.poi[n]} attach to the same trail point; added a 0.5 m link")
            n = twin
        g.poi[n] = iid
    tidy(g, prm)

    # connectivity from the gate
    gate_id = park.get("gate_poi")
    gate = next((n for n, iid in g.poi.items() if iid == gate_id), None)
    if gate is None:
        report.error(f"gate POI {gate_id} not attached to the graph")
        reach = set(g.pos)
    else:
        reach, q = {gate}, deque([gate])
        while q:
            n = q.popleft()
            for e in g.adj[n]:
                m = g.other(e, n)
                if m not in reach:
                    reach.add(m)
                    q.append(m)
    for n in list(g.pos):
        if n not in reach:
            if n in g.poi:
                report.error(f"{g.poi[n]} is not connected to the gate {gate_id} — a trail segment is missing")
            else:
                g.remove_node(n)
    stray = [n for n in g.pos if n not in reach]
    if any(n not in g.poi for n in stray):
        report.warn("dropped trail pieces not connected to the gate")

    # names: items keep their graph_node, junction waypoints name their junction, rest numbered
    node_name_of = {a[0]: a[1] for a in attach}
    names: dict[int, str] = {n: node_name_of[iid] for n, iid in g.poi.items()}
    used = set(names.values())
    for name, lat, lng in data.waypoints:
        if not name.upper().startswith("J") or name in used:
            continue
        p = proj.xy(lat, lng)
        cand = [n for n in g.pos if n not in names and g.degree(n) >= 3 and dist(p, g.pos[n]) <= prm.waypoint_snap_m]
        if cand:
            n = min(cand, key=lambda n: dist(p, g.pos[n]))
            names[n] = name
            used.add(name)
        else:
            report.warn(f"waypoint {name}: no trail junction within {prm.waypoint_snap_m:.0f} m — check the sheet")
    order = _bfs_order(g, gate if gate is not None else next(iter(g.pos)))
    counters = {"J": 0, "E": 0}
    for n in order:
        if n in names:
            continue
        prefix = "E" if g.degree(n) == 1 else "J"
        while True:
            counters[prefix] += 1
            cand = f"{prefix}{counters[prefix]:02d}"
            if cand not in used:
                break
        names[n] = cand
        used.add(cand)
        if prefix == "E":
            report.warn(f"{cand}: trail ends here without a POI ({_fmt(proj, g.pos[n])}) — dead end or unfinished recording?")

    # output
    nodes_json = []
    for n in order:
        lat, lng = proj.latlng(*g.pos[n][:2])
        ele = next((p[2] for e in g.adj[n] for p in [g.oriented(e, n)[0]] if p[2] is not None), None)
        nodes_json.append(
            {
                "id": names[n],
                "lat": round(lat, 6),
                "lng": round(lng, 6),
                "ele": round(ele, 1) if ele is not None else 0.0,
                "ref": g.poi.get(n),
                "coord_source": "SURVEY",
            }
        )
    edges_json = []
    adj_named: dict[str, list] = defaultdict(list)
    edge_by_pair: dict[tuple[str, str], dict] = {}
    for e in sorted(g.edges, key=lambda e: (order.index(g.edges[e].u), order.index(g.edges[e].v))):
        ed = g.edges[e]
        up, down = climb(ed.pts, prm.ele_gate_m)
        length = max(path_len(ed.pts), 0.5)
        geom = [proj.latlng(p[0], p[1]) for p in simplify(ed.pts, prm.simplify_m)]
        ej = {
            "from": names[ed.u],
            "to": names[ed.v],
            "length_m": round(length, 1),
            "ascent_m": round(up, 1),
            "descent_m": round(down, 1),
            "geometry": [[round(a, 6), round(b, 6)] for a, b in geom],
        }
        edges_json.append(ej)
        adj_named[ej["from"]].append((ej["to"], ej["length_m"]))
        adj_named[ej["to"]].append((ej["from"], ej["length_m"]))
        for key in ((ej["from"], ej["to"]), (ej["to"], ej["from"])):
            if key not in edge_by_pair or edge_by_pair[key]["length_m"] > ej["length_m"]:
                edge_by_pair[key] = ej

    graph_json = {
        "version": 1,
        "dummy": False,
        "generated_by": "tools/gpx_to_graph.py",
        "sources": sorted(data.files),
        "nodes": nodes_json,
        "edges": edges_json,
    }
    total = sum(e["length_m"] for e in edges_json)
    report.info(
        f"{len(data.tracks)} track(s) from {len(data.files)} file(s) → {len(nodes_json)} nodes, "
        f"{len(edges_json)} edges, {total / 1000:.2f} km of trail"
    )

    routes_json = None
    if update_routes:
        routes_json = _update_routes(content_dir, items, adj_named, edge_by_pair, report)

    geojson = _geojson(proj, g, names, attach, data.waypoints, edges_json, prm)
    return Result(graph_json, geojson, report, routes_json)


def _nearest_any(trails: SegmentIndex, p):
    """Nearest trail point at any distance (grows the search radius)."""
    r = 50.0
    while True:
        hit = trails.nearest(p, r)
        if hit is not None:
            return hit
        r *= 4
        if r > 1e6:
            raise RuntimeError("no trail found")


def _bfs_order(g: Graph, start: int) -> list[int]:
    order, seen, q = [], {start}, deque([start])
    while q:
        n = q.popleft()
        order.append(n)
        nbrs = sorted({g.other(e, n) for e in g.adj[n]}, key=lambda m: dist(g.pos[n], g.pos[m]))
        for m in nbrs:
            if m not in seen:
                seen.add(m)
                q.append(m)
    order += [n for n in g.pos if n not in seen]
    return order


def _fmt(proj: Projection, p) -> str:
    lat, lng = proj.latlng(*p[:2])
    return f"{lat:.6f},{lng:.6f}"


def _update_routes(content_dir, items, adj, edge_by_pair, report):
    routes_f = json.loads((content_dir / "routes.json").read_text(encoding="utf-8"))
    node_of = {iid: node_name for iid, node_name, *_ in items}
    for r in routes_f["routes"]:
        seq = [node_of[pid] for pid in r["poi_sequence"] if pid in node_of]
        path: list[str] = []
        for a, b in zip(seq, seq[1:]):
            leg = dijkstra(adj, a, b)
            if leg is None:
                report.error(f"route {r['id']}: no path {a} → {b}")
                break
            path += leg if not path else leg[1:]
        if not path:
            continue
        length = sum(edge_by_pair[(a, b)]["length_m"] for a, b in zip(path, path[1:]))
        ascent = sum(
            e["ascent_m"] if e["from"] == a else e["descent_m"]
            for a, b in zip(path, path[1:])
            for e in [edge_by_pair[(a, b)]]
        )
        report.info(
            f"route {r['id']}: {r.get('distance_m')} m → {length:.0f} m, "
            f"ascent {r.get('ascent_m')} → {ascent:.0f} m (duration_min left as is: needs survey timing)"
        )
        r["node_path"], r["distance_m"], r["ascent_m"] = path, round(length), round(ascent)
    return routes_f


def _geojson(proj, g, names, attach, waypoints, edges_json, prm) -> dict:
    feats = []
    for e in edges_json:
        feats.append(
            {
                "type": "Feature",
                "properties": {"kind": "edge", "from": e["from"], "to": e["to"], "length_m": e["length_m"], "stroke": "#3E8A5B"},
                "geometry": {"type": "LineString", "coordinates": [[b, a] for a, b in e["geometry"]]},
            }
        )
    for n in g.pos:
        lat, lng = proj.latlng(*g.pos[n][:2])
        kind = "item" if n in g.poi else ("end" if g.degree(n) == 1 else "junction")
        colour = {"item": "#1E4634", "end": "#B5482B", "junction": "#D99A2B"}[kind]
        feats.append(
            {
                "type": "Feature",
                "properties": {"kind": kind, "id": names[n], "ref": g.poi.get(n), "marker-color": colour},
                "geometry": {"type": "Point", "coordinates": [round(lng, 6), round(lat, 6)]},
            }
        )
    for iid, node_name, kind, p, q, d in attach:
        a, b = proj.latlng(*p[:2]), proj.latlng(*q[:2])
        flagged = d > prm.poi_warn_m
        feats.append(
            {
                "type": "Feature",
                "properties": {"kind": "attach", "id": iid, "offset_m": round(d, 1), "stroke": "#B5482B" if flagged else "#5F6B64"},
                "geometry": {"type": "LineString", "coordinates": [[a[1], a[0]], [b[1], b[0]]]},
            }
        )
    for name, lat, lng in waypoints:
        feats.append(
            {
                "type": "Feature",
                "properties": {"kind": "waypoint", "name": name, "marker-color": "#2F6FB0", "marker-symbol": "w"},
                "geometry": {"type": "Point", "coordinates": [lng, lat]},
            }
        )
    return {"type": "FeatureCollection", "features": feats}


def main(argv: list[str] | None = None) -> int:
    # Windows consoles default to cp1252, which can't print "→" in the report lines.
    for stream in (sys.stdout, sys.stderr):
        if hasattr(stream, "reconfigure"):
            stream.reconfigure(errors="replace")
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("gpx", nargs="+", type=Path, help="GPX files or folders containing *.gpx")
    ap.add_argument("--content", type=Path, default=ROOT / "assets" / "content")
    ap.add_argument("--out", type=Path, default=None, help="default: <content>/trail_graph.json")
    ap.add_argument("--geojson", type=Path, default=ROOT / "build" / "gpx_to_graph" / "preview.geojson")
    ap.add_argument("--update-routes", action="store_true", help="rewrite routes.json node_path/distance/ascent")
    ap.add_argument("--force", action="store_true", help="write trail_graph.json even with errors")
    ap.add_argument("--merge-m", type=float, default=Params.merge_m)
    args = ap.parse_args(argv)

    paths: list[Path] = []
    for p in args.gpx:
        paths += sorted(p.glob("*.gpx")) if p.is_dir() else [p]
    if not paths:
        print("ERROR   no .gpx files found")
        return 1
    prm = Params(merge_m=args.merge_m)
    res = run(paths, args.content, prm, update_routes=args.update_routes)
    rep = res.report

    args.geojson.parent.mkdir(parents=True, exist_ok=True)
    args.geojson.write_text(json.dumps(res.geojson), encoding="utf-8")
    for m in rep.infos:
        print(f"INFO    {m}")
    for m in rep.warnings:
        print(f"WARNING {m}")
    for m in rep.errors:
        print(f"ERROR   {m}")
    print(f"preview: {args.geojson} (open on https://geojson.io)")

    if rep.errors and not args.force:
        print(f"\n{len(rep.errors)} error(s): trail_graph.json NOT written (fix the data or use --force)")
        return 1
    out = args.out or args.content / "trail_graph.json"
    out.write_text(json.dumps(res.graph_json, indent=2, ensure_ascii=False) + "\n", encoding="utf-8", newline="\n")
    print(f"wrote {out}")
    if res.routes_json is not None:
        rp = args.content / "routes.json"
        rp.write_text(json.dumps(res.routes_json, indent=2, ensure_ascii=False) + "\n", encoding="utf-8", newline="\n")
        print(f"wrote {rp}")
    print("next: python tools/validate_content.py && flutter test")
    return 1 if rep.errors else 0


if __name__ == "__main__":
    sys.exit(main())
