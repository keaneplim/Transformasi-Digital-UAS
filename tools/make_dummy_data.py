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

from narration import content_fields  # audio narration + its sources (docs/content/narration/)

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
    # Added 2026-11-12 from survey photos (photo = real, position = still DUMMY layout).
    ("FS06", "toilet", "Toilet dekat Gua Belanda", 510, 1100, ["toilet", "wc", "kamar mandi"]),
    ("FS07", "musala", "Musala dekat Gua Belanda", 525, 1130, ["musala", "mushola", "masjid", "salat", "sholat"]),
    ("FS08", "istirahat", "Saung Penangkaran Rusa", 740, 1295, ["istirahat", "saung", "gazebo", "duduk", "teduh"]),
    ("FS09", "istirahat", "Saung Jalur Gua", 436, 873, ["istirahat", "saung", "gazebo", "duduk", "teduh"]),
    ("FS10", "istirahat", "Gazebo Jalur Kolam", 175, 420, ["istirahat", "gazebo", "saung", "duduk", "foto"]),
]
# Survey photos (assets/images/). Real photos of real places; see survey/raw/photo_waypoints.csv.
IMAGES = {
    "P01": ["p01_gerbang.jpg"], "P04": ["p04_papan.jpg"],  # P04 photo [VERIFIKASI]: is this Kolam Pakar?
    "P06": ["p06_mulut_gua.jpg", "p06_lorong.jpg"], "P07": ["p07_rusa.jpg"],
    "FS01": ["fs01_toilet.jpg"], "FS06": ["fs06_toilet.jpg"], "FS07": ["fs07_musala.jpg"],
    "FS08": ["fs08_saung.jpg"], "FS09": ["fs09_saung.jpg"], "FS10": ["fs10_gazebo.jpg"],
}
# UI mock copy (2026-11-12). OBSERVATIONAL ONLY: atmosphere, what a visitor sees, walking tips.
# No dates, builders, functions or other historical claims (PRD §8.2). Shown only while "text"
# is still an [ISI] placeholder; replace by sourced text from the manager/signboards.
DRAFT_TEXT = {
    "P01": "Di sinilah perjalanan Anda dimulai. Gerbang batu berlengkung tiga ini menjadi penanda masuk kawasan hutan, dengan deretan pinus tinggi yang langsung menyambut di baliknya. Udara terasa lebih sejuk begitu Anda melangkah masuk. Sebelum berjalan lebih jauh, pastikan botol minum terisi, alas kaki nyaman, dan baterai ponsel cukup. Peta dan cerita di aplikasi ini sudah tersimpan di ponsel, jadi tetap bisa dipakai walau sinyal hilang di tengah hutan. Pilih rute yang sesuai tenaga Anda hari ini, lalu nikmati jalan setapak yang teduh menuju gua dan titik-titik menarik lainnya.",
    "P02": "Sebuah monumen berdiri di area terbuka yang dikelilingi pepohonan, menjadi salah satu titik paling mudah dikenali di awal jalur. Banyak pengunjung berhenti sejenak di sini untuk berfoto dan mengatur napas sebelum melanjutkan perjalanan. Perhatikan papan informasi di sekitarnya untuk mengenal tokoh yang namanya diabadikan menjadi nama taman hutan raya ini. Area sekitarnya relatif datar dan cocok untuk anak-anak. Saat siang hari, cari sisi yang teduh di bawah pohon, lalu dengarkan narasi singkat sambil menikmati suasana hutan kota yang tenang dan jauh dari bising jalan raya.",
    "P03": "Bangunan museum ini menjadi tempat yang tepat untuk mengenal kawasan lebih dalam sebelum masuk ke hutan. Di dalamnya, pengunjung dapat melihat koleksi dan papan informasi tentang taman hutan raya dan tokoh yang namanya digunakan. Luangkan waktu sekitar dua puluh menit untuk berkeliling dengan santai. Ruangan yang teduh juga cocok sebagai tempat beristirahat sejenak bagi keluarga dengan anak. Periksa jam buka museum di pintu masuk, karena dapat berbeda dari jam buka kawasan. Setelah dari sini, jalur akan mulai menurun perlahan menuju kolam dan area gua.",
    "P04": "Jalur di sekitar titik ini dikelilingi pohon pisang berdaun lebar dan semak hijau yang rimbun. Di dekatnya terdapat shelter beratap hijau dan papan informasi tentang aliran air dan bendungan di kawasan Bandung Utara. Suara air dan kicau burung membuat tempat ini terasa tenang, cocok untuk berhenti sebentar sebelum menuju gua. Jalan setapak di sekitar air bisa licin setelah hujan, jadi melangkahlah dengan hati-hati dan awasi anak-anak di dekat pagar. Baca papan informasi di lokasi untuk memahami peran air di kawasan hutan ini, lalu lanjutkan perjalanan mengikuti petunjuk arah.",
    "P05": "Mulut gua terbuka di dinding tebing yang ditumbuhi tanaman paku dan lumut. Begitu melangkah masuk, cahaya meredup dan udara terasa lembap serta jauh lebih dingin dibanding jalur di luar. Lorong-lorongnya bercabang, sehingga sebaiknya Anda tetap bersama rombongan dan mengikuti jalur yang umum dilalui pengunjung. Bawa senter atau gunakan lampu ponsel, dan perhatikan lantai yang bisa basah. Di dalam gua sinyal lokasi biasanya melemah; jika cerita tidak muncul otomatis, pindai kode QR pada papan informasi. Dengarkan narasinya perlahan sambil membayangkan lorong-lorong ini di masa lalu.",
    "P06": "Pintu masuk gua ini berupa lengkungan batu berdinding putih kapur dengan pagar besi hijau di sisinya. Di dalam, lorong panjang menembus bukit dan terasa sejuk sepanjang hari. Langkah kaki dan suara pengunjung bergema pelan di dinding batu. Gunakan senter dan berjalanlah di sisi kiri agar arus pengunjung tetap lancar. Sepeda tidak diperbolehkan masuk. Jika sinyal lokasi melemah di dalam lorong, pindai kode QR di dekat pintu masuk untuk membuka cerita. Setelah keluar, sempatkan beristirahat di saung terdekat sebelum melanjutkan perjalanan ke penangkaran rusa.",
    "P07": "Di balik pagar kawat, area terbuka berumput menjadi tempat rusa merumput dan berteduh di bawah pepohonan. Jika beruntung, Anda dapat melihat beberapa rusa bergerak perlahan atau beristirahat di kejauhan. Amati dengan tenang dan jangan memberi makan sembarangan, karena makanan yang tidak sesuai dapat membuat satwa sakit. Hindari suara keras dan jangan memasukkan tangan ke dalam pagar. Papan informasi di depan kandang mengajak pengunjung menjaga satwa agar tetap lestari. Tempat ini cocok untuk mengenalkan anak-anak pada satwa, sambil beristirahat di saung yang ada di sekitarnya.",
    "P08": "Barisan pohon pinus tinggi menjulang dengan batang lurus dan tajuk yang menyaring cahaya matahari menjadi berkas-berkas lembut. Lantai hutan tertutup daun jarum kering yang empuk diinjak dan beraroma khas. Ini tempat yang baik untuk memperlambat langkah, menarik napas dalam, dan menikmati udara hutan yang sejuk. Banyak pengunjung beristirahat di bangku sekitar sambil minum air. Jika Anda mengikuti rute Wellness, inilah saat yang pas untuk peregangan ringan. Jaga kebersihan dengan membawa kembali sampah Anda, dan jangan menyalakan api di area yang dipenuhi daun kering ini.",
    "P09": "Hamparan rumput terbuka ini menjadi ruang lapang di tengah rimbunnya hutan. Keluarga sering menggelar tikar, anak-anak berlarian, dan pengunjung lain sekadar duduk menikmati angin. Pilih tempat yang teduh di tepi pepohonan saat matahari terik. Area ini cocok untuk makan bekal dan beristirahat lebih lama sebelum melanjutkan perjalanan. Mohon jaga kebersihan dengan membawa pulang sampah dan tidak merusak tanaman di sekitarnya. Jika cuaca mendung, perhatikan langit dan bersiaplah kembali ke jalur, karena tanah berumput bisa cepat becek dan licin setelah turun hujan.",
    "P10": "Di sepanjang potongan jalur ini, beragam tanaman tumbuh berdampingan dan sebagian diberi label nama. Perhatikan perbedaan bentuk daun, tekstur batang, dan warna bunga dari satu tanaman ke tanaman lain. Titik ini cocok untuk pelajar yang datang dalam rangka kunjungan edukasi, atau siapa pun yang ingin mengenal isi hutan lebih dekat. Berjalanlah perlahan dan baca label yang tersedia. Mohon tidak memetik daun, bunga, atau buah, agar koleksi tetap dapat dinikmati pengunjung berikutnya. Foto dan catatan sudah cukup untuk dibawa pulang sebagai kenang-kenangan dari jalur ini.",
    "P11": "Titik ini berada di ujung rute Trekking dan membutuhkan tenaga lebih untuk mencapainya. Jalur menuju ke sana lebih panjang, menanjak, dan di beberapa bagian berbatu. Suara gemuruh air akan terdengar sebelum air terjunnya terlihat. Pastikan waktu masih cukup untuk kembali ke gerbang sebelum kawasan tutup, bawa air minum yang cukup, dan kenakan alas kaki yang kuat. Jangan mendekati tepi tebing atau berenang di area arus deras. Nikmati pemandangan dari tempat yang aman, beristirahatlah secukupnya, lalu kembali melalui jalur yang sama dengan hati-hati.",
}
SAFETY = {
    "P05": "Bawa senter. Lorong gelap, lembap, dan lantainya bisa licin.",
    "P06": "Bawa senter dan tetap bersama rombongan. Sepeda dilarang masuk.",
    "P11": "Jalur menanjak dan berbatu. Jangan mendekati tepi tebing atau arus deras.",
}
JUNCTIONS = [("J01", 0, 200), ("J02", 150, 450), ("J03", 300, 700), ("J04", 400, 900)]
# undirected edges between node ids (POI node = N_<id>, facility node = N_<id>)
EDGES = [
    ("N_P01", "J01"), ("N_P01", "N_FS01"), ("J01", "N_P02"), ("J01", "N_FS02"), ("J01", "N_P10"),
    ("N_P02", "N_P03"), ("N_P03", "J02"), ("J02", "N_P04"), ("N_P04", "N_FS03"), ("N_P04", "J03"),
    ("J02", "N_P08"), ("N_P08", "N_FS05"), ("N_P08", "N_P09"), ("N_P09", "J03"),
    ("J03", "N_P05"), ("N_P05", "J04"), ("J04", "N_P06"), ("N_P06", "N_FS04"), ("N_P06", "N_P07"),
    ("N_P07", "N_P11"), ("N_P10", "N_P08"),
    ("N_P06", "N_FS06"), ("N_P06", "N_FS07"), ("N_P07", "N_FS08"), ("J04", "N_FS09"), ("J02", "N_FS10"),
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
        "draft_text": DRAFT_TEXT[pid],
        "key_facts": [], "images": IMAGES.get(pid, []), "audio": None, "audio_seconds": None,
        "routes": routes, "safety_note": SAFETY.get(pid), "sources": [],
    })
    pois_out[-1].update(content_fields(pid))

facilities_out = []
for fid, ftype, name, x, y, kw in FACILITIES:
    n = nodes[f"N_{fid}"]
    facilities_out.append({"id": fid, "type": ftype, "name": name, "lat": n["lat"], "lng": n["lng"],
                           "coord_source": "DUMMY", "graph_node": f"N_{fid}", "keywords": kw,
                           "images": IMAGES.get(fid, [])})

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
