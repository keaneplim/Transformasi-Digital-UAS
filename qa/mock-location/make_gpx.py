"""Generate mock-location GPX tracks for QA from the app's trail graph and POI data.

Usage (from the repo root): python qa/mock-location/make_gpx.py . qa/mock-location/gpx
Tracks follow the trail-graph geometry at walking speed (park.json walk_speed_m_per_min), one point per second,
with stationary pauses (small jitter) where a scenario needs the tester to stay put.
"""
import heapq
import json
import math
import os
import random
import sys
from datetime import datetime, timedelta, timezone

ROOT, OUT = sys.argv[1], sys.argv[2]
os.makedirs(OUT, exist_ok=True)
J = lambda p: json.load(open(os.path.join(ROOT, p), encoding="utf-8"))
graph = J("assets/content/trail_graph.json")
pois = {p["id"]: p for p in J("assets/content/pois.json")["pois"]}
facs = {f["id"]: f for f in J("assets/content/facilities.json")["facilities"]}
routes = {r["id"]: r for r in J("assets/content/routes.json")["routes"]}
park = J("assets/content/park.json")
SPEED = park["params"]["walk_speed_m_per_min"] / 60.0  # m/s
nodes = {n["id"]: n for n in graph["nodes"]}
R = 6371000.0
random.seed(7)


def hav(a, b):
    la1, lo1, la2, lo2 = map(math.radians, (a[0], a[1], b[0], b[1]))
    h = math.sin((la2 - la1) / 2) ** 2 + math.cos(la1) * math.cos(la2) * math.sin((lo2 - lo1) / 2) ** 2
    return 2 * R * math.asin(math.sqrt(h))


adj = {}
for e in graph["edges"]:
    geo = [tuple(p) for p in e["geometry"]]
    a, b = e["from"], e["to"]
    full = [(nodes[a]["lat"], nodes[a]["lng"])] + geo + [(nodes[b]["lat"], nodes[b]["lng"])]
    adj.setdefault(a, []).append((b, e["length_m"], full))
    adj.setdefault(b, []).append((a, e["length_m"], list(reversed(full))))


def dijkstra(s, t):
    dist, prev, pq = {s: 0}, {}, [(0, s)]
    while pq:
        d, u = heapq.heappop(pq)
        if u == t:
            break
        if d > dist.get(u, 1e18):
            continue
        for v, w, g in adj.get(u, []):
            nd = d + w
            if nd < dist.get(v, 1e18):
                dist[v], prev[v] = nd, (u, g)
                heapq.heappush(pq, (nd, v))
    path, u = [], t
    while u != s:
        p, g = prev[u]
        path = g + path[1:] if path else g
        u = p
    return dedupe(path)


def chain(node_ids):
    pts = []
    for a, b in zip(node_ids, node_ids[1:]):
        seg = dijkstra(a, b)
        pts = pts + seg[1:] if pts else seg
    return dedupe(pts)


def dedupe(pts):
    out = []
    for p in pts:
        if not out or hav(out[-1], p) > 0.3:
            out.append(p)
    return out


def length(pts):
    return sum(hav(a, b) for a, b in zip(pts, pts[1:]))


def cut_tail(pts, metres):
    """Last `metres` of a polyline."""
    acc, i = 0.0, len(pts) - 1
    while i > 0 and acc < metres:
        acc += hav(pts[i - 1], pts[i])
        i -= 1
    return pts[i:]


def point_at(pts, metres):
    acc = 0.0
    for a, b in zip(pts, pts[1:]):
        d = hav(a, b)
        if acc + d >= metres:
            f = (metres - acc) / d if d else 0
            return (a[0] + (b[0] - a[0]) * f, a[1] + (b[1] - a[1]) * f), (a, b)
        acc += d
    return pts[-1], (pts[-2], pts[-1])


def offset(p, dn, de):
    return (p[0] + math.degrees(dn / R), p[1] + math.degrees(de / (R * math.cos(math.radians(p[0])))))


def perp(seg, metres):
    (a, b) = seg
    dn = math.radians(b[0] - a[0]) * R
    de = math.radians(b[1] - a[1]) * R * math.cos(math.radians(a[0]))
    n = math.hypot(dn, de) or 1
    return -de / n * metres, dn / n * metres  # left normal


class Track:
    def __init__(self):
        self.t = datetime(2026, 11, 24, 6, 0, 0, tzinfo=timezone.utc)  # 13.00 WIB
        self.pts = []

    def _add(self, p):
        self.pts.append((p, self.t))
        self.t += timedelta(seconds=1)

    def walk(self, poly):
        if self.pts and hav(self.pts[-1][0], poly[0]) > 0.5:
            poly = [self.pts[-1][0]] + poly
        total = length(poly)
        steps = max(1, int(total / SPEED))
        for i in range(steps + 1):
            self._add(point_at(poly, total * i / steps)[0])
        return self

    def stay(self, seconds, at=None):
        p = at or self.pts[-1][0]
        for _ in range(int(seconds)):
            self._add(offset(p, random.uniform(-0.3, 0.3), random.uniform(-0.3, 0.3)))
        return self

    def go(self, p):
        return self.walk([self.pts[-1][0], p])

    def write(self, name, desc):
        path = os.path.join(OUT, name)
        with open(path, "w", encoding="utf-8", newline="\n") as f:
            f.write('<?xml version="1.0" encoding="UTF-8"?>\n')
            f.write('<gpx version="1.1" creator="Jelajah Taman QA mock-location generator" '
                    'xmlns="http://www.topografix.com/GPX/1/1">\n')
            f.write(f"  <metadata><name>{name}</name><desc>{desc}</desc></metadata>\n")
            f.write(f"  <trk><name>{name[:-4]}</name><trkseg>\n")
            for (lat, lng), t in self.pts:
                f.write(f'    <trkpt lat="{lat:.7f}" lon="{lng:.7f}"><time>{t.strftime("%Y-%m-%dT%H:%M:%SZ")}</time></trkpt>\n')
            f.write("  </trkseg></trk>\n</gpx>\n")
        dur = (self.pts[-1][1] - self.pts[0][1]).total_seconds()
        dist = length([p for p, _ in self.pts])
        return name, dur, dist


def P(pid):
    x = pois.get(pid) or facs.get(pid)
    return (x["lat"], x["lng"])


def node_of(pid):
    x = pois.get(pid) or facs.get(pid)
    return x["graph_node"]


def dist_from(poly_rev, poi, metres):
    """Point on a polyline (walking away from poi) at straight-line distance `metres` from poi."""
    acc_pt = poly_rev[0]
    for a, b in zip(poly_rev, poly_rev[1:]):
        for k in range(1, 21):
            q = (a[0] + (b[0] - a[0]) * k / 20, a[1] + (b[1] - a[1]) * k / 20)
            if hav(q, poi) >= metres:
                return q
            acc_pt = q
    return acc_pt


made = []
p05 = P("P05")
r05 = pois["P05"]["radius_m"]
to_p05 = dijkstra(node_of("P01"), node_of("P05")) + [p05]
approach = cut_tail(to_p05, 220)
away = list(reversed(to_p05))  # path leaving P05 back toward the gate

made.append(Track().walk(approach).stay(240).write(
    "01_mendekati_P05_lalu_diam_4mnt.gpx",
    f"Berjalan ±220 m menuju Gua Jepang (P05, r={r05} m), lalu diam 4 menit di titik POI."))

out45 = dist_from(away, p05, r05 + 25)
made.append(Track().stay(30, p05).go(out45).stay(60).go(p05).stay(120).write(
    "02_keluar_masuk_cepat_P05.gpx",
    f"Mulai di P05, keluar ke ±{r05 + 25} m (> r+15), tunggu 1 menit, kembali sebelum 10 menit, diam 2 menit."))

out60 = dist_from(away, p05, r05 + 40)
made.append(Track().stay(30, p05).go(out60).stay(660).go(p05).stay(120).write(
    "03_keluar_masuk_lewat_10mnt_P05.gpx",
    f"Mulai di P05, keluar ke ±{r05 + 40} m, tunggu 11 menit (lewat cooldown), kembali ke P05, diam 2 menit."))

e47, e57, e75 = (dist_from(away, p05, r05 + d) for d in (27, 37, 55))
lead = cut_tail(to_p05, 220)
lead = lead[: next(i for i, q in enumerate(lead) if hav(q, p05) <= r05 + 42)]
t = Track().walk(lead)
t.go(e57).go(e47)
for _ in range(6):
    t.go(e57).stay(10).go(e47).stay(10)
t.go(e75).stay(30).go(e47).stay(30)
made.append(t.write(
    "04_tepi_zona_mendekati_P05.gpx",
    f"Mondar-mandir di tepi zona mendekati P05 ({r05 + 27}–{r05 + 37} m, antara r+30 dan r+40) selama ±3 menit, "
    f"lalu menjauh ke {r05 + 55} m (> r+40) dan mendekat lagi."))

made.append(Track().stay(60, P("P07")).walk(dijkstra(node_of("P07"), node_of("P09"))).stay(60, P("P09")).write(
    "05_P07_ke_P09_berdekatan.gpx", "Diam 1 menit di Penangkaran Rusa (P07), lalu jalan ke Area Piknik (P09) yang radiusnya bertumpuk, diam 1 menit."))


sant = routes["santai"]
t = Track()
seq_nodes = [node_of(p) for p in sant["poi_sequence"]]
for a, b in zip(seq_nodes, seq_nodes[1:]):
    t.walk(dijkstra(a, b)).stay(90)
made.append(t.write("06_rute_santai_penuh.gpx",
                    "Rute Santai penuh (" + " → ".join(sant["poi_sequence"]) + "), diam 90 detik di setiap POI."))

sed = routes["sedang"]
t = Track()
seq_nodes = [node_of(p) for p in sed["poi_sequence"]]
for a, b in zip(seq_nodes, seq_nodes[1:]):
    t.walk(dijkstra(a, b)).stay(60)
made.append(t.write("06b_rute_sedang_10_poi.gpx",
                    "Rute Sedang penuh (" + " → ".join(sed["poi_sequence"]) + "), diam 60 detik di setiap POI. Melewati 10 POI inti."))

to_p06 = dijkstra(node_of("P01"), node_of("P06")) + [P("P06")]
made.append(Track().stay(20, P("P01")).walk(to_p06).stay(120).write(
    "07_navigasi_gerbang_ke_P06.gpx", "Dari gerbang (P01) mengikuti jalur ke Gua Belanda (P06), diam 2 menit di tujuan."))

L = length(to_p06)
t = Track().stay(20, P("P01"))
p40, seg40 = point_at(to_p06, L * 0.35)
p60, seg60 = point_at(to_p06, L * 0.6)
first = [q for q in to_p06 if True]
t.walk([q for q in to_p06][: max(2, next(i for i in range(len(to_p06)) if length(to_p06[:i + 1]) >= L * 0.35))] + [p40])
t.go(offset(p40, *perp(seg40, 15))).stay(30).go(p40)
idx60 = next(i for i in range(len(to_p06)) if length(to_p06[:i + 1]) >= L * 0.6)
idx40 = next(i for i in range(len(to_p06)) if length(to_p06[:i + 1]) >= L * 0.35)
t.walk([p40] + to_p06[idx40:idx60] + [p60])
t.go(offset(p60, *perp(seg60, 50))).stay(40).go(p60)
t.walk([p60] + to_p06[idx60:]).stay(60)
made.append(t.write("08_navigasi_menyimpang.gpx",
                    "Navigasi P01 → P06: di ±35% menyimpang 15 m selama 30 detik (tidak boleh hitung ulang), "
                    "di ±60% menyimpang 50 m selama 40 detik (harus hitung ulang), lalu kembali dan tiba."))

made.append(Track().stay(20, P("P06")).walk(dijkstra(node_of("P06"), node_of("FS06")) + [P("FS06")]).stay(120).write(
    "09_ke_toilet_FS06.gpx", "Dari Gua Belanda (P06) ke Toilet dekat Gua Belanda (FS06), diam 2 menit. Fasilitas tidak boleh memicu."))

made.append(Track().stay(600, P("P01")).write("10_diam_di_gerbang_P01.gpx", "Diam 10 menit di gerbang (P01)."))

for n, d, m in made:
    print(f"{n:42} {int(d // 60):3d}:{int(d % 60):02d}  {m:6.0f} m")
