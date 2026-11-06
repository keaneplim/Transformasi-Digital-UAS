# IMPLEMENTATION PLAN — Jelajah Taman

Feature-level specification and build plan for the 3 coders. It is derived from **PRD v0.9** (`PRD_Kelompok5_Jelajah_Taman.docx`). The PRD says *what* each requirement must do; this document says *how we build it, who builds it, in what order, and how we prove it works*.

- **If this file and the PRD disagree, the PRD wins** until the change is approved and written into the PRD Change Log (§10). Items marked **PROPOSED** below are decisions this plan needs that the PRD does not make (or makes inconsistently). The team must confirm them, then record them in the PRD.
- `[VERIFIKASI]` values (coordinates, opening hours, route lengths, history facts) are **not** filled in here. Code reads them from data files, so they can be updated after the survey without touching code.
- Current status and open issues live in [PROGRESS.md](../../PROGRESS.md). Issue numbers like "#8" refer to its *Known issues* table.

---

## Contents
0. [Team, ownership, schedule](#0-team-ownership-schedule)
1. [Decisions to confirm before coding](#1-decisions-to-confirm-before-coding)
2. [Architecture](#2-architecture)
3. [Data model & content files](#3-data-model--content-files)
4. [Shared contracts (agree on day 1)](#4-shared-contracts-agree-on-day-1)
5. [Feature specifications](#5-feature-specifications)
   - [F01 Location Awareness](#f01--location-awareness) · [F02 Location-Based Trigger](#f02--location-based-trigger) · [A02 QR Fallback](#a02--qr-fallback-trigger) · [A06 Battery-Aware Tracking](#a06--battery-aware-tracking)
   - [A01 Offline Map](#a01--offline-mode--offline-map) · [F06 Navigation](#f06--navigation) · [F05 Search](#f05--search--destination) · [A04 Facility Finder](#a04--facility-finder)
   - [F03 Multimodal POI Detail](#f03--multimodal-exploration-poi-detail) · [F04 Eyes-Free](#f04--eyes-free-interaction) · [A05 Data-Driven Content](#a05--data-driven-content)
   - [F07 Recommendation](#f07--contextual-recommendation) · [A03 Closing Reminder](#a03--closing-time-reminder)
   - [F08 Wellness Trail Explorer](#f08--wellness-trail-explorer) · [A07 Accessibility](#a07--accessibility)
   - [App shell: Onboarding, Home, Session, Settings](#app-shell--onboarding-ui01-home-ui02-session-lifecycle-settings-ui15)
6. [Cross-cutting concerns](#6-cross-cutting-concerns)
7. [Testing strategy & TC mapping](#7-testing-strategy--tc-mapping)
8. [W12 Major Progress Review demo script](#8-w12-major-progress-review-demo-script)
9. [Risks](#9-risks)

---

## 0. Team, ownership, schedule

### 0.1 Who does what

| Role | Person | Owns |
|---|---|---|
| **Coder A — "Where am I"** + integrator | Michael Ballard Silaen | F01, F02, A02, A06 → then F07, A03. App skeleton, `LocationService`, `TriggerEngine`, `SessionLog`, debug tools (GPX replay, fake clock). Merges to `main`, keeps the build installed on the test phones. |
| **Coder B — "Where do I go"** | _TBD_ | A01 (map), F06, F05, A04. `TrailRouter` (graph, Dijkstra, ETA), map widget. |
| **Coder C — "What do I experience"** | _TBD_ | F03, F04, A05 loader → then F08, A07, Onboarding/Home/Settings. `AudioService`, `TtsService`, notifications (`notify`), content repository. |
| **Content & data** (non-coder) | _TBD_ (BA fits) | Survey (coordinates, GPX, photos, walk times), `pois.json` / `routes.json` / `park.json` contents, narration scripts + recordings, source log for every fact, PRD updates. |
| **Design & QA** (non-coder) | _TBD_ | Hi-fi screens **one sprint ahead** of the coder building them, GPX replay files, test scripts TC-01…TC-13, field + usability tests (SUS), AI & Tools Disclosure log. |

PM duties (permits, PMO, W12 report) go to whichever non-coder is the PM, or are shared.

### 0.2 Sprint schedule per coder

| Sprint | Coder A | Coder B | Coder C | Non-coders |
|---|---|---|---|---|
| **S2** (2–8 Nov) | Project skeleton, `LocationService`, GPX replay + debug menu, `TriggerEngine` + unit tests, QR scanner | Offline map + markers + user dot, GPX → graph script, stub `TrailRouter` (day 1) | Content loader + validation, POI Detail, audio player, notifications | Survey, `pois.json` v1, scripts + recordings, hi-fi UI03–UI07, GPX replay files |
| **S3** (9–15 Nov) **W12 review** | Integrate trigger → POI Detail, screen-off tracking, GPS-weak flow, session log | Dijkstra, Navigation screen, reroute, arrival, Search | Lock-screen media controls, Auto-Play, TTS prompts, Onboarding, Home | Hi-fi UI08–UI15, run TC-04/05/07 on device, prepare demo |
| **S4** (16–22 Nov) **feature freeze** | F07 recommendation, A03 closing reminder | Voice turn instructions, slope ETA, ETA calibration vs survey times, A06 support if needed | F08: routes screen, pedometer, distance, hydration, summary; Settings; A07 | Calibrate data, TC-09/10/11/12 dry runs |
| **S5** (23–29 Nov) | Radius calibration in the field, trigger bug fixes | ETA vs actual, routing fixes | Usability fixes, accessibility scan | Field test TC-01…13, usability + SUS, video, testing report |

### 0.3 Working rules
1. **Day 1 (before any feature code): agree on §3 and §4.** Coder B ships a stub `TrailRouter` (haversine × 1.3) the same day so A and C never wait.
2. **One PR per feature slice, reviewed by one other coder** (A↔B, B↔C, C↔A). The reviewer must be able to explain the code — this is the PRD §8.2 verification rule for AI-assisted code.
3. **No PR merges without its unit tests** (geofence, routing, recommendation, reminders, content validation).
4. **Everything location- or time-dependent is testable at a desk** via `GpxReplayLocationSource` and `FakeClock` (§6.5). Nobody should need to go to Tahura to test a code change.
5. Branches: `feat/<area>-<short>` → PR → `main`. `main` must always build.
6. **Day 1 together:** all three coders build T01–T02 (location + GPX replay + debug menu) as a group. Every location feature depends on it, and it gives everyone a working knowledge of the core. Split into A / B / C from day 2.

### 0.4 Task list

Coder A = Michael Ballard Silaen · Coder B = _TBD_ · Coder C = _TBD_. Within a wave the three coders work **in parallel**; the waves run in order. A task can start as soon as everything in "Needs first" is done (or stubbed).

| Wave | Dates (2026) | Goal |
|---|---|---|
| 0 | now → Sun 8 Nov | Foundations every other task needs |
| 1 | Mon 9 → Wed 11 Nov | Core engines (trigger, router, notifications) |
| 2 | Thu 12 Nov → W12 review | End-to-end demo: Start → Explore → Trigger → Information → Search → Navigation + eyes-free |
| 3 | S4, 16–22 Nov (feature freeze) | Recommendation, reminders, Wellness, Settings, accessibility |

Critical paths: (1) T01 → T08 → T09 → T11/T15 → T22 (the core demo); (2) survey GPX → T13 → T14 → T19 (navigation on real data).

| ID | Task | Owner | Needs first | Wave | Status |
|---|---|---|---|---|---|
| T01 | `LocationService` + `GeolocatorSource` (3 s, foreground service, GPS quality) | A | — | 0 | ☐ |
| T02 | `GpxReplaySource` + debug menu (replay picker, fake clock, teleport, debug overlay) | A | T01 | 0 | ☐ |
| T03 | Minimal permission request (location, notifications) so testing can start. Proper onboarding UI is T18. | A | — | 0 | ☐ |
| T04 | Explore map UI03: MBTiles tiles, POI/facility markers, geofence rings, user dot | B | T01 (or teleport) | 0 | ☐ |
| T05 | Offline tiles: generate `dago_pakar.mbtiles` legally (not bulk-downloaded from OSM's servers) | B | — | 0 | ☐ |
| T06 | POI Detail UI06: gallery, text, facts, player widget; publishes `PoiEngaged`/`PoiFinished` | C | content (done) | 0 | ☐ |
| T07 | `AudioService`: narration (file or TTS fallback), `TtsService` with Indonesian voice check | C | — | 0 | ☐ |
| T08 | `TriggerEngine` (pure): state machine, debounce, hysteresis, cooldown, rules D01–D05, plus the 9 unit tests | A | T01 | 1 | ☐ |
| T09 | Trigger controller: fixes → engine → events; approaching banner UI04 | A | T08 | 1 | ☐ |
| T10 | QR scanner UI12 + payload parsing + printed QR boards (P05/P06) | A | T08 | 1 | ☐ |
| T11 | `notify` module: channels, trigger notification with Dengarkan/Lihat/Nanti actions, vibration | C | — | 1 | ☐ |
| T12 | **Spike (half a day, A+C, by Tue 10 Nov):** can "Dengarkan" start audio from the lock screen without opening the app? | A+C | T07, T11 | 1 | ☐ |
| T13 | `tools/gpx_to_graph.py` → real `trail_graph.json` from survey GPX | B | survey | 1 | ☐ |
| T14 | Real `TrailRouter`: snapping, Dijkstra on time cost, ETA with slope (D09) + tests | B | T13 (dummy graph is fine to start) | 1 | ☐ |
| T15 | Lock-screen/earphone media controls, Auto-Play, voice prompt on trigger, `VoiceArbiter` | C | T07, T11 | 1–2 | ☐ |
| T16 | Session module: start/end/restore, `SessionLog` (triggered vs visited), `visit_events` table | A | T08 | 2 | ☐ |
| T17 | GPS-weak banner (60 s) + manual POI pick | A | T09 | 2 | ☐ |
| T18 | Onboarding UI01 (permission flow, battery exemption, TTS check) + Home UI02 (interests, route chooser, *Mulai Jelajah*) | C | T16 (start session) | 2 | ☐ |
| T19 | Navigation UI10/UI11: route line, remaining distance/ETA, arrival (never triggers, D06), reroute | B | T14, T04 | 2 | ☐ |
| T20 | Search UI09 + facility finder (A04): matching (D12), filter, sort by walking distance | B | T14 (stub works) | 2 | ☐ |
| T21 | Explore screen composition: map + banners + bottom sheet (built in the `shell` module) | B | T04, T09 | 2 | ☐ |
| T22 | W12 end-to-end run on replay + demo video | all | T01–T21 | 2 | ☐ |
| T23 | `ReminderScheduler` + closing reminder (A03) | A | T14, T16 | 3 | ☐ |
| T24 | Recommendation F07 (filter + `ScoreFactor`s + UI08) | A | T14, T16 | 3 | ☐ |
| T25 | Battery-aware tracking (A06) | A | T01, T27 | 3 | ☐ |
| T26 | Voice turn instructions + ETA calibration against survey times | B | T19, survey | 3 | ☐ |
| T27 | Wellness: pedometer, GPS distance, kcal, stats strip | C | T01, T16 | 3 | ☐ |
| T28 | Hydration reminder (a `Reminder` strategy plugged into T23's scheduler) | C | T23 | 3 | ☐ |
| T29 | Session summary UI14 + Settings UI15 | C | T16, T27 | 3 | ☐ |
| T30 | Accessibility pass (A07), contrast fix #19 | C | screens | 3 | ☐ |

**Why these pairings** (same owner on purpose):
- **Trigger + QR + Session → A.** They all change the same per-POI state; splitting them means two people editing one state machine.
- **Recommendation + closing reminder → A.** Same time budget (walk to POI + visit + walk to gate ≤ closing − 15 min); written once.
- **Hydration → C, plugged into A's `ReminderScheduler`.** Open/Closed in practice: a new `Reminder` class, no edits to the scheduler.
- **Map + Navigation + Explore screen → B.** Navigation draws on the map's layers; one owner for the Explore screen file. A and C hand over their pieces (approaching banner, stats strip) as widgets.
- **Search + Router → B.** Results are sorted by walking distance from the router.
- **POI Detail + Audio + Notifications + Eyes-free → C.** One user experience with one voice-priority system (`VoiceArbiter`).

**Scope rules for the W12 review:** waves 0–2 only. Say explicitly that Recommendation and Wellness (wave 3) are Sprint 4 scope. T05 (map tiles) may slip: for W12, trail lines from `trail_graph.json` on a plain background are acceptable.

Update the Status column (☐ → ◐ in progress → ☑ done) in the same PR that delivers the task.

---

## 1. Decisions to confirm before coding

These are gaps or contradictions in PRD v0.9 that block implementation. Each has a **PROPOSED** default so coding can start. Confirm or change in the team meeting, then add to the PRD Change Log and sync docx → pdf → pptx per CLAUDE.md.

| ID | Problem (PROGRESS #) | PROPOSED decision | Blocks |
|---|---|---|---|
| **D01** | Flowchart checks only the single nearest POI, so a visited POI can mask an untriggered neighbour (#8) | Evaluate **every eligible POI** (state `Outside`/`Approaching`) each reading. Among those meeting the trigger condition, trigger the nearest. POIs in `Triggered/Visited/Cooldown` are skipped. | PB06 |
| **D02** | Approaching buzz fires before the visited/cooldown check (#9) | Approaching only applies to eligible POIs. **One buzz per approach episode.** | PB06, PB07 |
| **D03** | No hysteresis on Approaching: enter and exit both at r+30 → repeated buzz at the boundary (#4) | Enter Approaching at ≤ r+30 m, exit back to Outside only at > r+40 m. | PB06 |
| **D04** | Cooldown start ambiguous (#3) | Re-trigger allowed only when **both** hold: user has been > r+15 m at least once since the trigger, **and** ≥10 min have passed **since the trigger time**. | PB06 |
| **D05** | "Nanti" marks the POI visited, so walk-bys count as visits (#11) | Separate **triggered** from **visited**. Visited = user chose *Dengarkan* or *Lihat*, Auto-Play started narration, user opened POI Detail by any route, or QR scan. *Nanti*/dismiss = triggered only, stays a recommendation candidate. | PB06, PB15, PB18 |
| **D06** | Navigation "tiba ≤15 m" routes into TRIGGER → double trigger; facilities would also trigger (#10) | Arrival **never creates a trigger.** It announces arrival (UI11). If the destination is a POI not yet visited, UI11 offers *Buka detail*. Facilities: announcement only. | PB14 |
| **D07** | P01 "offer to start session" is impossible because triggers only run in a session (#12) | P01 is not handled by the trigger engine. When Home is open (no session) and a foreground location fix is within P01's radius, Home shows a "Anda di Gerbang Dago Pakar — Mulai Jelajah?" banner. | UI02 |
| **D08** | "GPS lemah > 60 s" rule is only in the figure and slide 8 (#15) | Keep it: if every reading for 60 s has accuracy > 30 m (or no fix), show the UI12 banner: *Pindai QR* / *Pilih manual*. Add to PRD F02 text. | PB10 |
| **D09** | F06 slope formula unspecified (#16) | Naismith-style: `t = horizontal_m / 50 m·min⁻¹` (3 km/h) `+ 1 min per 10 m ascent`. Descent adds nothing. Calibrate against survey walk times in S4. | PB14 |
| **D10** | F07 weights unspecified (#16) | `score = 0.50·dist + 0.25·interest + 0.15·route + 0.10·difficulty` (definitions in F07). | PB15 |
| **D11** | F08 calorie method unspecified; no body weight (#16) | MET-based estimate, optional body weight in Settings stored on-device only (allowed by NG05: nothing on a server). Default 60 kg, shown as "estimasi". | PB16 |
| **D12** | F05 typo tolerance has no rule (#16) | Normalize → substring/prefix match → else Levenshtein ≤1 (query length 4–6) or ≤2 (≥7). Plus a `keywords` alias list per item (e.g., "wc" → toilet). | PB13 |
| **D13** | Scenario reminder time 14.45 contradicts the A03 formula (#2, #14) | **The formula is authoritative.** Fix the scenario text and TC-10. TC-10 must fix a tester position and walk time so the expected time is deterministic. | PB17, TC-10 |
| **D14** | Location settings "±3 s or ≥3 m": a distance filter of 3 m means a stationary user gets no readings, so the 2-reading debounce and the 60 s GPS-weak timer can stall | Request updates every 3 s with **distance filter 0**; filter in app. A06 lengthens the interval when stationary. | PB02 |

---

## 2. Architecture

**The full architecture is in [ARCHITECTURE.md](ARCHITECTURE.md)** (modular monolith, module catalogue, dependency rules, event catalogue, Open/Closed extension points, enforcement). This section only summarizes it.

### 2.1 Modules and levels (summary)
| Level | Modules (owner) |
|---|---|
| 0 | `core` — Clock, geo, EventBus + events, DB, logging, theme |
| 1 | `content` (C) · `location` (A) · `audio` (C) · `notify` (C) |
| 2 | `routing` (B) · `trigger` (A) |
| 3 | `session` (A) · `map` (B) · `navigation` (B) · `poi` (C) |
| 4 | `search` (B) · `recommendation` (A) · `reminders` (A closing / C hydration) · `wellness` (C) |
| 5 | `shell` (C, wiring with A) — onboarding, Home, Settings, composition root, debug menu |

A module may depend only on lower levels, through its public file `lib/modules/<m>/<m>.dart`. Questions go through direct calls, news through domain events. This is enforced by `tools/check_architecture.dart` in CI.

### 2.2 Repository layout (outside `lib/`)

```
lib/core/ · lib/modules/<module>/{<module>.dart, src/{domain,data,application,ui}}   (see ARCHITECTURE.md §7)
assets/
  content/  pois.json  facilities.json  routes.json  park.json  trail_graph.json
  images/   p05_1.webp …
  audio/    p05.mp3 …  prompts/ (optional pre-recorded voice prompts)
  map/      dago_pakar.mbtiles
tools/      gpx_to_graph.py, validate_content.py, check_architecture.dart  (run on laptop / CI, not in the app)
test/       mirrors lib/ (test/modules/<m>/...) + content_test.dart
test_data/  gpx/ (replay tracks), fixtures for TC-09/TC-10
```

### 2.3 Packages (from PRD §8.1)
`geolocator` (with its Android foreground-notification option for screen-off tracking) · `flutter_map` + an MBTiles tile provider · `just_audio` + `audio_service` · `flutter_tts` · `mobile_scanner` · `flutter_local_notifications` · `vibration` · `pedometer` · `sqflite` + `shared_preferences` · `go_router` · `permission_handler` · `flutter_riverpod` (no code generation, ADR-002). Pin exact versions in `pubspec.yaml` and don't upgrade during S4–S5.

---

## 3. Data model & content files

All content and tunable parameters live in `assets/content/*.json` (A05). **Changing a radius, a text, or the opening hours must not require a code change.** The content owner edits these files; `tools/validate_content.py` and `test/content_test.dart` must pass before merge.

### 3.1 `pois.json` (extends the PRD §4.1 schema)
```json
{
  "version": 1,
  "pois": [{
    "id": "P05",
    "name": "Gua Jepang",
    "category": "sejarah",                 // sejarah | alam | rekreasi  (facilities go in facilities.json)
    "lat": 0.0, "lng": 0.0,                 // [VERIFIKASI] from survey
    "radius_m": 20,
    "trigger": ["gps", "qr"],
    "qr_code": "jelajahtaman://poi/P05",
    "visit_minutes": 15,
    "difficulty": 2,                        // NEW: 1 easy · 2 medium · 3 hard (access to this POI)
    "graph_node": "N_P05",                  // NEW: node id in trail_graph.json
    "keywords": ["gua", "jepang", "goa"],   // NEW: search aliases (D12)
    "text": "...",                          // 80–150 words
    "key_facts": ["..."],
    "images": ["p05_1.webp"],
    "audio": "p05.mp3",                     // null → TTS reads `text`
    "audio_seconds": 90,
    "routes": ["santai", "sedang", "trekking"],
    "safety_note": "...",
    "sources": ["Papan informasi Gua Jepang, foto survei 2026-11-xx"]   // NEW: required for every fact (PRD §8.2)
  }]
}
```

### 3.2 `facilities.json`
```json
{ "facilities": [{ "id": "FS01", "type": "toilet", "name": "Toilet dekat Gerbang",
   "lat": 0.0, "lng": 0.0, "graph_node": "N_FS01", "keywords": ["toilet","wc","kamar mandi"] }] }
```
`type` ∈ `toilet | musala | warung | pos_petugas | istirahat`. Facilities **never** trigger (A04).

### 3.3 `routes.json`
```json
{ "routes": [{ "id": "santai", "name": "Santai", "difficulty": 1,
   "distance_m": 0, "ascent_m": 0, "duration_min": 0,      // [VERIFIKASI] from GPX survey
   "poi_sequence": ["P01","P02","P05","P06","P01"],
   "node_path": ["N_P01","J03","N_P02", "..."] }] }
```

### 3.4 `park.json` — operating hours and every tunable parameter
```json
{
  "hours": { "open": "08:00", "close": "16:00", "verified": false },   // [VERIFIKASI]
  "gate_poi": "P01",
  "params": {
    "gps_interval_s": 3, "gps_weak_accuracy_m": 30, "gps_weak_banner_after_s": 60,
    "approach_margin_m": 30, "approach_exit_margin_m": 40,
    "debounce_readings": 2, "retrigger_exit_margin_m": 15, "cooldown_min": 10,
    "arrival_m": 15, "offroute_m": 30, "offroute_readings": 2,
    "walk_speed_m_per_min": 50, "ascent_min_per_10m": 1,
    "closing_buffer_min": 15, "hydration_default_min": 45,
    "rec_weights": { "dist": 0.50, "interest": 0.25, "route": 0.15, "difficulty": 0.10 }
  }
}
```

### 3.5 `trail_graph.json` (generated by `tools/gpx_to_graph.py`, not hand-written)
```json
{ "nodes": [{ "id": "J03", "lat": 0.0, "lng": 0.0, "ele": 0.0, "ref": null }],     // ref = "P05"/"FS01" or null for a junction
  "edges": [{ "from": "J03", "to": "N_P02", "length_m": 0.0, "ascent_m": 0.0, "descent_m": 0.0,
              "geometry": [[lat,lng], ...] }] }                                     // undirected; ascent/descent stored for from→to
```

### 3.6 On-device storage
| Store | Content |
|---|---|
| SQLite `sessions` | id, started_at, ended_at, route_id, interests, steps_start, steps_end, distance_m, active_seconds |
| SQLite `visit_events` | session_id, poi_id, event (`approaching`/`triggered`/`visited`/`dismissed`), source (`gps`/`qr`/`manual`/`nav`), at, lat, lng, accuracy_m |
| SQLite `activity_samples` | session_id, at, lat, lng, accuracy_m, steps (for distance & debugging; also field-test evidence) |
| SharedPreferences | onboarding_done, interests, auto_play, hydration_min, text_scale, body_weight_kg, voice_nav_on |

`visit_events` doubles as the **test log evidence** required by PRD §4.2 point 5 (ID, time, source, accuracy).

---

## 4. Shared contracts (agree on day 1)

These signatures are the only coupling between the three coders. Change them only by PR approved by all three. Business news (trigger, visited, session start/end, arrival, reminders) travels as **domain events E1–E10**, listed in [ARCHITECTURE.md §5.2](ARCHITECTURE.md#52-event-catalogue-the-whole-list--keep-it-short). Interfaces below cover questions, commands and data streams only.

```dart
// core/clock — every "now" in the app comes from here (enables TC-10 simulation)
abstract class Clock { DateTime now(); }

// modules/location — owner A
enum GpsQuality { good, weak, none }
class LocationFix { final double lat, lng, accuracyM; final double? speedMps, headingDeg; final DateTime at; }
abstract class LocationService {
  Stream<LocationFix> get fixes;          // every fix, incl. weak ones (UI shows them)
  Stream<GpsQuality> get quality;         // good ≤30 m, weak >30 m, none = no fix 10 s
  LocationFix? get last;
  Future<void> startSession();            // starts foreground service, 3 s interval
  Future<void> stopSession();
}

// modules/trigger — owner A
// Publishes E3 PoiApproached, E4 PoiTriggered, E6 PoiVisited, E7 PoiFinished(leftArea).
// Listens to E5 PoiEngaged (from poi/audio/navigation) to move a POI to Visited (D05).
enum PoiState { outside, approaching, triggered, visited, cooldown }
// TriggerSource { gps, qr, manual } lives in core/events (used in event payloads)
abstract class TriggerEngine {
  Map<String, PoiState> get states;
  void onQrScanned(String poiId);         // jumps straight to Triggered + Visited (PRD §4.2)
  void onManualPick(String poiId);
}

// modules/session — owner A
abstract class SessionLog {
  Set<String> get triggeredPoiIds;
  Set<String> get visitedPoiIds;          // D05
  String? get lastVisitedPoiId;
  Stream<void> get changes;
}

// modules/routing — owner B   (stub on day 1: haversine × 1.3, ETA = d / 50)
class RouteResult { final List<GeoPoint> polyline; final List<String> nodeIds; final double distanceM; final Duration eta; final List<TurnInstruction> turns; }
abstract class TrailRouter {   // not "Router": clashes with Flutter's Router widget
  RouteResult? route(GeoPoint from, String toNodeId);
  double walkingDistanceM(GeoPoint from, String toNodeId);
  Duration walkingTime(GeoPoint from, String toNodeId);        // incl. slope (D09)
  Duration walkingTimeBetween(String fromNodeId, String toNodeId);
}

// modules/audio — owner C   (publishes E5 PoiEngaged(listened/autoplay), E7 PoiFinished(narrationDone))
enum VoicePriority { safety, navigation, triggerPrompt, reminder }
abstract class TtsService { Future<void> say(String text, {VoicePriority priority}); }
abstract class AudioService {
  Future<void> playNarration(String poiId);   // file, or TTS fallback when audio == null
  Future<void> pause(); Future<void> resume(); Future<void> replay();
  Stream<PlaybackState> get state;
}

// core/content — owner C (schema agreed with content owner)
abstract class ContentRepository {
  List<Poi> get pois; List<Facility> get facilities; List<TrailRoute> get routes;
  ParkConfig get park; TrailGraph get graph;
  Poi? poiById(String id); Poi? poiByQr(String payload);
}
```

**Integration order:** `ContentRepository` + `Clock` (day 1) → `LocationService` → `TriggerEngine` + stub `TrailRouter` → POI Detail + `AudioService` → real `TrailRouter` → Search/Navigation → Recommender/Wellness.

---

## 5. Feature specifications

Each feature uses the same template: **Summary → Use cases → Rules → Implementation → Acceptance criteria ↔ tests → Edge cases → Done when.**
Actors: **Pengunjung** (visitor), **GPS** (device GNSS), **Clock**, **QR board**.

---

### F01 — Location Awareness
**Owner** A · **Sprint** S1–S2 (PB02), screen-off in S3 · **Screens** UI01 (permission), UI03 (blue dot), UI12 (GPS weak) · **Priority** Must

**Summary.** Read the device position at high accuracy every ~3 s, show it as a blue dot with an accuracy circle on the offline map, flag readings > 30 m as "GPS lemah" (shown, but not used for triggers), and keep reading with the screen off while a session is active.

#### Use cases
**UC-F01-1 See my position**
- *Precondition:* location permission granted; device location on.
- *Main flow:* 1) Visitor opens Explore (UI03). 2) System requests fixes (3 s, high accuracy). 3) System draws blue dot + accuracy circle + heading cone within ≤10 s in open sky. 4) Dot moves as visitor walks. 5) Status chip shows "GPS baik · ±8 m".
- *Postcondition:* `LocationService.last` is current; fixes are logged to `activity_samples` during a session.

**UC-F01-2 GPS becomes weak**
- *Trigger:* fix accuracy > 30 m (canopy, valley, cave).
- *Flow:* chip turns Clay Red "GPS lemah · ±45 m"; dot is still drawn with the large accuracy circle; `TriggerEngine` ignores the fix. After 60 s of weak/no fix → UI12 banner (D08) offering *Pindai QR* / *Pilih manual*.
- *Recovery:* the first good fix hides the banner automatically.

**UC-F01-3 Permission denied**
- *Flow:* UI01 explains why location is needed ("untuk memicu informasi saat Anda tiba di objek"). If denied: app still works; Explore shows the map without a dot; the trigger mode becomes QR + manual pick; Search sorts by name with "jarak tidak tersedia". A persistent chip offers *Aktifkan lokasi* (opens app settings if "don't ask again").

**UC-F01-4 Screen off during a session**
- *Flow:* Visitor locks the phone. A foreground service with an ongoing notification ("Jelajah Taman sedang memandu Anda") keeps fixes flowing; triggers still fire (F02/F04).

#### Rules
| Rule | Value | Source |
|---|---|---|
| Update interval | 3 s, distance filter 0 (D14) | F01, `park.json` |
| Accuracy mode | high (Fused, GNSS) | F01 |
| Weak threshold | accuracy > 30 m → `GpsQuality.weak` | F01 |
| No fix | no fix for 10 s → `GpsQuality.none` | PROPOSED |
| GPS-weak banner | 60 s weak/none | D08 |
| Background | foreground service only during a session | F01, NG06 (no tracking outside session) |

#### Implementation
- `GeolocatorLocationSource` wraps `geolocator.getPositionStream` with Android settings: high accuracy, `intervalDuration: 3s`, `distanceFilter: 0`, and the foreground notification config when a session starts.
- `GpxReplayLocationSource` (debug) replays a `.gpx` file at real or ×N speed, with optional injected noise/accuracy values. **Both implement the same source interface**; `LocationService` doesn't know which is active.
- `LocationService` emits every fix on `fixes`, derives `quality`, and keeps `last`. It never filters for triggers — that's `TriggerEngine`'s job.
- Map layer (owned by B) subscribes to `fixes` to draw the dot.
- Manifest: `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`, `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_LOCATION` (Android 14+), `POST_NOTIFICATIONS` (13+). A foreground service started while the app is visible does **not** need `ACCESS_BACKGROUND_LOCATION`; don't request it.

#### Acceptance criteria ↔ tests
| AC (PRD F01) | How we verify |
|---|---|
| (1) Position shown ≤10 s after permission, open area | TC-01, stopwatch from permission tap to dot |
| (2) Updates when walking 20 m | TC-01 |
| (3) Deviation ≤15 m on ≥80% of measurements vs survey reference points | TC-01: ≥10 measurements at surveyed points, compare logged fix vs reference |
| (4) Denied → explanation + manual/QR still usable | Device test, deny permission |
| (5) "GPS lemah" when accuracy > 30 m | Unit test with replay fixes at 35 m accuracy; field check under canopy |

#### Edge cases
- Location services switched off at OS level → treat as `none`, show *Aktifkan GPS*.
- Mock/unstable first fixes (accuracy 100+ m) right after start → shown as weak, ignored for triggers.
- OEM battery killers (Xiaomi/Oppo/Vivo) stop the service with the screen off → see Risk R2; onboarding asks to exempt the app from battery optimization.

#### Done when
Dot is shown and updated on ≥2 test phones in airplane mode (GPS works without data); weak chip and banner appear on replay; screen-off session keeps logging fixes for 15 min; unit tests for quality derivation pass.

---

### F02 — Location-Based Trigger
**Owner** A · **Sprint** S2 (PB06 engine, PB07 notifications), S3 integration · **Screens** UI04 Approaching, UI05 Trigger notification · **Priority** Must

**Summary.** For each POI, compute haversine distance on each accepted fix and run a per-POI state machine (Outside → Approaching → Triggered → Visited → Cooldown) with a 2-reading debounce, hysteresis, and 10-min cooldown. Fire a vibration + sound when approaching, and a notification + voice prompt when triggered.

#### Use cases
**UC-F02-1 Approach a POI**
- *Precondition:* session active; POI eligible (state `outside`); fix accuracy ≤30 m.
- *Main flow:* 1) Visitor's distance to POI ≤ r+30 m. 2) System: state → `approaching`; one short vibration + sound (D02); UI04 banner "Gua Jepang · 45 m" with live distance; geofence ring pulses.
- *Alternate:* distance goes back > r+40 m → `outside`, banner hides, no new buzz until a new episode (D03).

**UC-F02-2 Arrive at a POI (trigger)**
- *Main flow:* 1) Two consecutive accepted fixes ≤ r. 2) System: state → `triggered`; logs `triggered` event (source gps, accuracy); posts high-priority notification "Anda tiba di Gua Jepang" with actions **Dengarkan · Lihat · Nanti**; voice prompt "Anda tiba di Gua Jepang. Ingin mendengar sejarahnya?" (F04). 3) If Auto-Play is on, narration starts ≤3 s (F04).
- *Branch Dengarkan:* narration plays without opening the app → audio publishes `PoiEngaged(listened)` → engine moves POI to Visited (D05).
- *Branch Lihat:* opens POI Detail (≤2 s) → poi publishes `PoiEngaged(opened)` → Visited.
- *Branch Nanti / swipe away:* event `dismissed`; POI stays `triggered`, **not visited**.
- *Postcondition:* POI cannot trigger again until D04 conditions hold.

**UC-F02-3 Overlapping POIs**
- *Flow:* visitor is inside the radius of two eligible POIs. System triggers the **nearest** one only (D01). The other is evaluated again on the next fixes; it triggers once the visitor is still inside its radius on 2 readings **and** at least 30 s passed since the previous trigger (PROPOSED: avoids two notifications stacking at once).

**UC-F02-4 Linger inside radius**
- *Flow:* visitor stays/wanders inside the radius for 3 min → no new notification (TC-03).

**UC-F02-5 Leave and come back**
- *Flow:* visitor goes > r+15 m, returns within 10 min of the trigger → no re-trigger (F02 AC3). Returns after ≥10 min and having left > r+15 m → trigger again (D04).

**UC-F02-6 Walk past an already-visited POI**
- *Flow:* POI is `visited`/`cooldown` → no approaching buzz, no trigger (D01, D02).

#### State machine (per POI)
```
            d ≤ r+30                 2× d ≤ r                 PoiEngaged (E5)
 OUTSIDE ───────────► APPROACHING ───────────► TRIGGERED ───────────────► VISITED
    ▲   ◄───────────      │                       │                          │
    │     d > r+40        │ 2× d ≤ r (direct)     │ (Nanti: stays TRIGGERED)  │
    │                     ▼                       ▼                          ▼
    │                 (also allowed: OUTSIDE → TRIGGERED if first two fixes are inside r)
    │                                          left > r+15 at least once  AND  now − triggeredAt ≥ 10 min
    └──────────────────────────────────────────────────── COOLDOWN (eligible again → OUTSIDE)
```
- QR scan / manual pick: any state → `triggered` (+ `visited` immediately for QR, since the user acted) — PRD §4.2.
- Weak fixes (> 30 m) do not count toward debounce and do **not** reset it either (PROPOSED: a weak fix between two good ones inside r shouldn't cancel the trigger).
- Debounce counter resets when a good fix lands outside r.

#### Rules
| Rule | Value | Source |
|---|---|---|
| Radius r | per POI, 20–40 m, from `pois.json` | §4.1 |
| Approaching enter / exit | ≤ r+30 / > r+40 | F02, D03 |
| Debounce | 2 consecutive good fixes ≤ r | F02 |
| Re-trigger | exit > r+15 **and** ≥10 min since trigger | F02, D04 |
| Overlap | nearest eligible first | F02, D01 |
| Facilities | never evaluated | A04 |
| P01 | not a trigger in-session (welcome only once per session, silent card); pre-session offer on Home | D07 |
| P11 | evaluated only when active route = trekking | §4.1 |

#### Implementation
- `TriggerEngine` is **pure Dart, no Flutter imports**: input = `LocationFix` + `Clock.now()`, output = list of domain events (E3/E4/E6/E7) that `TriggerController` then publishes on the bus (ARCHITECTURE.md §7.2). This makes it unit-testable with tables of fixes.
- Per POI keep: `state`, `debounceCount`, `triggeredAt`, `leftRetriggerZone`, `approachBuzzed`.
- Each fix: drop if accuracy > 30 m → for each eligible POI compute d → update approaching → collect candidates with `debounceCount ≥ 2` → trigger nearest.
- Distance: haversine; the zone is ~2 km wide, so precision is fine. No need for the OS geofencing API (PRD §4.2 says not to use it).
- `NotificationService` (`notify` module, C) posts the trigger notification when trigger's reaction asks it to; `TtsService` (C) speaks the prompt; `vibration` for approaching (pattern: one 300 ms pulse).
- Log every event to `visit_events`.

#### Unit tests (must exist before merge — PB06 done criterion)
1. Walk-in replay → exactly one `Approaching`, then one `Triggered`.
2. Single fix inside r then outside → no trigger (debounce).
3. 3 min of jitter inside r → one trigger only (TC-03 at desk).
4. Exit > r+15 and re-enter at minute 5 → no trigger; at minute 11 → trigger.
5. Two overlapping POIs, A visited → B triggers (D01 regression for #8).
6. Visited POI walk-by → no approaching buzz (D02 / #9).
7. Boundary oscillation r+28 ↔ r+35 → one buzz only (D03 / #4).
8. Weak fixes ignored; weak fix between two good inside fixes still triggers.
9. QR scan → `Triggered(source: qr)` regardless of GPS state.

#### Acceptance criteria ↔ tests
| AC (PRD F02) | Verify |
|---|---|
| (1) Correct notification ≤10 s on entry, ≥8 of 10 POIs | TC-02 field; at desk via replay |
| (2) No repeat within radius for 3 min | TC-03 + unit test 3 |
| (3) Exit > r+15 and re-enter < 10 min → no re-trigger | TC-03 + unit test 4 |
| (4) Approaching buzz at ≤ r+30 | Unit test 1; field observation |
| (5) QR opens correct POI ≤3 s offline | TC-04 (see A02) |
| *(missing in PRD)* false triggers | PROPOSED AC: during TC-02, count triggers for POIs the tester didn't enter; target 0 false triggers on the route. Add to PRD. |

#### Edge cases
- GPS jump of 50 m into a radius for one fix → debounce absorbs it.
- Two POIs closer than their radii sum (e.g., Monumen/Museum if adjacent) → handled by D01 + 30 s spacing; content owner should flag such pairs after the survey so radii can be tuned.
- Notification permission denied → in-app banner + voice only; tell the user in UI01.
- Session paused/killed → engine state persisted to SQLite so a restarted app doesn't re-trigger everything.

#### Done when
All 9 unit tests pass; replay of a full Santai GPX triggers each route POI exactly once on a real phone with the screen locked; the notification actions work from the lock screen.

---

### A02 — QR Fallback Trigger
**Owner** A · **Sprint** S2 (PB10) · **Screens** UI12 · **Priority** Must

**Summary.** In-app scanner reads `jelajahtaman://poi/<ID>` from boards at the cave mouths (P05, P06) and GPS-weak spots, resolves the ID locally (offline), and opens the POI as a trigger.

#### Use cases
**UC-A02-1 Scan a cave QR**
- *Entry points:* UI12 banner *Pindai QR* (auto after 60 s weak GPS), Explore toolbar QR button, POI Detail "di dalam gua?" hint.
- *Flow:* 1) Camera permission requested on first use. 2) Scanner opens in Cave Mode (dark UI, torch toggle). 3) Code decoded → `ContentRepository.poiByQr()` → `TriggerEngine.onQrScanned()` → POI Detail opens ≤3 s; event logged with source `qr`.
- *Postcondition:* POI `triggered` + `visited`.

**UC-A02-2 Unknown or foreign QR**
- *Flow:* payload not matching `jelajahtaman://poi/` or ID not in data → message "QR tidak dikenali. Pastikan Anda memindai papan Jelajah Taman." Scanner stays open.

**UC-A02-3 Manual pick (last resort)**
- *Flow:* *Pilih manual* → list "Di sekitar saya" (nearest by last known good fix; if none, all POIs alphabetically) → tap → `onManualPick()` → POI Detail.

**UC-A02-4 QR scanned outside the app** (phone camera)
- Deep link `jelajahtaman://poi/P05` registered as an Android intent filter opens the app on that POI. Nice-to-have, S3 if time allows.

#### Implementation
- `mobile_scanner` with `formats: [BarcodeFormat.qrCode]`, torch button, timeout-free.
- Print QR boards: ≥8 cm wide, high error correction (H), POI name printed under the code so the visitor knows which board is which. Permission to mount is a PM item (Lampiran B #6).

#### Acceptance criteria ↔ tests
TC-04: scan P05/P06 in airplane mode → correct POI ≤3 s; scan an unrelated QR → error message. Unit test for payload parsing (valid, wrong scheme, unknown ID, lowercase id, trailing slash).

#### Done when
Both cave QRs printed and opening the right POI offline on 2 phones; manual pick works with location denied.

---

### A06 — Battery-Aware Tracking
**Owner** A · **Sprint** S4 (after core works) · **Priority** Could

**Summary.** Lengthen the GPS interval when the visitor is stationary to save battery. Target ≤15% battery per hour of session.

#### Rules (PROPOSED)
| State | Detect | Interval |
|---|---|---|
| Moving | steps increasing **or** speed > 0.5 m/s | 3 s |
| Stationary | no new steps and speed < 0.3 m/s for 60 s | 10 s |
| Back to moving | first new step from the pedometer stream | 3 s immediately |
| Approaching any POI | always | 3 s (never slow down near a POI) |

#### Implementation
`LocationService` re-subscribes with a new interval on state change. Uses the pedometer stream from `WellnessTracker` (C) as the wake-up signal — the one cross-coder dependency of this feature.

#### Verify
Battery test: full-charge phone, 60-min session with screen off, record % drop on both test phones (TC log entry, PB21). Keep the screen-off rate in the testing report.

---

### A01 — Offline Mode & Offline Map
**Owner** B · **Sprint** S1–S2 (PB05) · **Screens** UI03 Explore Map · **Priority** Must

**Summary.** The zone map, POI data, photos, audio and trail graph ship **inside the APK**, so every core feature works in airplane mode from first launch. (The PRD allows "download once"; bundling is simpler and removes a failure mode at the park gate with weak signal.)

#### Use cases
**UC-A01-1 Explore the map offline**
- *Flow:* Visitor opens Explore in airplane mode → map tiles of the Dago Pakar zone render from the bundled MBTiles; POI markers (category tint + icon), facility markers, active route line, user dot, geofence rings; bottom sheet peek shows session stats (steps, distance, time, POIs visited x/10).
- *Interactions:* tap marker → POI preview card (name, distance, ETA, *Detail*, *Navigasi*); recenter button; zoom limited to the zone bounds.

**UC-A01-2 First launch with no internet** — works fully; nothing to download.

#### Implementation
- **Tiles:** produce `dago_pakar.mbtiles` for the zone bounding box, zoom ~14–18. **Do not bulk-download from `tile.openstreetmap.org`** — the OSM tile usage policy forbids it. Render our own tiles from OSM data (e.g., with an offline renderer / tile generator on a laptop) or use a provider whose licence allows offline packaging. Show "© OpenStreetMap contributors" attribution on the map (ODbL).
- Overlay our own surveyed trail lines from `trail_graph.json` on top of the tiles, because OSM may not have every footpath in Tahura.
- `flutter_map` with: tile layer (MBTiles provider), polyline layer (trails, active route), circle layer (geofence rings: dashed r, faint r+30), marker layer (POIs, facilities, visited check badge, amber halo for triggered), user-location layer.
- Camera bounds clamped to the zone; initial view fits the active route.
- APK size budget: tiles ≤60 MB, audio ~10 MB (10 × ~90 s mono MP3 64 kbps), images ~5 MB (WebP ≤1280 px). Measure in S2.

#### Acceptance criteria ↔ tests
PB05: map, markers, user dot visible in airplane mode. A01 AC / TC-13: run F01–F08 end to end in airplane mode (S5).

#### Edge cases
Visitor outside the zone (e.g., at home) → dot off-map; show "Anda di luar zona Dago Pakar" chip; triggers simply never fire. Dark Cave Mode map style is optional (DESIGN.md §7) — only if time allows.

#### Done when
Tiles + overlays render offline on 2 phones at 60 fps panning; attribution visible; zone clamp works.

---

### F06 — Navigation
**Owner** B · **Sprint** S3 (PB12 graph, PB14 navigation), voice turns + slope calibration S4 · **Screens** UI10 Navigation, UI11 Arrived · **Priority** Must

**Summary.** Pedestrian routing on a trail graph built from survey GPX tracks: Dijkstra shortest path, drawn on the offline map with remaining distance, ETA (3 km/h + slope correction), voice instructions at junctions, arrival at ≤15 m, reroute when > 30 m off route.

#### Use cases
**UC-F06-1 Navigate to a POI or facility**
- *Entry points:* POI preview *Navigasi*, POI Detail, Search result, Recommendation sheet (one tap, F07 AC5), Closing reminder *Navigasi ke gerbang* (A03).
- *Precondition:* a good fix exists (else: "Menunggu GPS…" and route from the last good fix, labelled approximate).
- *Main flow:* 1) System snaps the user to the nearest point on the nearest edge. 2) Dijkstra to the destination node. 3) UI10 draws the route (Canopy Deep line), top card shows next instruction ("Di pertigaan, ambil jalur kiri menurun · 80 m"), bottom shows remaining distance + ETA + elevation sparkline; ≤3 s total. 4) Remaining distance and ETA update on each fix. 5) Voice instruction ~20 m before each turn node (F04e). 6) At ≤15 m from destination → UI11 "Anda tiba di Toilet dekat Gerbang", voice announcement.
- *Postcondition (D06):* arrival never creates a trigger. If destination is an unvisited POI → UI11 shows *Buka detail* (opening it marks visited, source `nav`).

**UC-F06-2 Go off route**
- *Flow:* distance from user to route polyline > 30 m on 2 consecutive good fixes → "Menghitung ulang rute…" → new route ≤5 s → voice "Rute diperbarui".

**UC-F06-3 Cancel navigation** — *Akhiri navigasi* button returns to Explore; session continues.

**UC-F06-4 GPS weak during navigation** — keep the last route displayed, freeze ETA, show weak chip; don't reroute on weak fixes.

#### Graph construction (`tools/gpx_to_graph.py`, run on a laptop — PB12)
1. Load all survey GPX tracks; drop points with poor HDOP/accuracy; smooth (moving average 3).
2. Simplify (Douglas–Peucker, ~3 m tolerance).
3. Detect junctions: points where tracks come within ~8 m of each other or cross → merge into one junction node.
4. Split tracks at junctions into edges; compute `length_m` (sum of haversine), `ascent_m`/`descent_m` from elevation (smoothed; phone GPS elevation is noisy — prefer a DEM or barometric logger if available).
5. Attach every POI/facility to its nearest edge point as a node (`N_P05`); **flag any POI > 25 m from a trail** for the survey team to check.
6. Verify connectivity: every POI/facility node reachable from `N_P01` (PB12 done criterion). Output `trail_graph.json` + a GeoJSON preview to view on a map.

#### Routing & ETA
- Dijkstra over ≤ a few hundred nodes → microseconds; no need for A*.
- Edge cost = **time** (not length), so slopes affect the choice: `t = length_m / 50 + ascent_m / 10` minutes (D09; parameters from `park.json`).
- `walkingDistanceM(from, node)` = distance to snapped edge point + path length. Used by Search (F05), Recommendation (F07), Closing reminder (A03).
- Calibration (S4): compare graph ETA with survey walk times per route segment; adjust `walk_speed_m_per_min` and `ascent_min_per_10m`. Target: ETA error ≤25% (F06 AC6).

#### Turn instructions
- At each node with degree ≥3 on the route: compute bearing change between incoming and outgoing segments (using geometry ~15 m on each side). `|Δ| < 30°` → "lurus"; 30–150° → "kiri"/"kanan"; add "menanjak"/"menurun" when the next 50 m climbs/descends > 5 m.
- Voice text template: "Dalam 20 meter, di pertigaan, ambil jalur kiri menurun." Spoken through `TtsService` with `VoicePriority.navigation`.
- Degree-2 nodes (bends in a single trail) get no instruction.

#### Acceptance criteria ↔ tests
| AC (PRD F06) | Verify |
|---|---|
| (1) Follows footpaths, shown ≤3 s | TC-08; unit test: route between two nodes equals expected node list on a fixture graph |
| (2) Distance/ETA decrease while walking | Replay test |
| (3) Reach 3 different POIs only by following navigation | TC-08 field |
| (4) Reroute ≤5 s after > 30 m deviation | TC-08; replay with a detour track |
| (5) Works in airplane mode | TC-13 |
| (6) ETA vs actual ≤25% | TC-08: stopwatch per leg |

#### Edge cases
- Destination unreachable (graph gap) → message "Rute tidak tersedia" + straight-line distance; this should never ship — the connectivity check prevents it.
- User exactly at a junction when routing starts → snap to node.
- Navigation and a POI trigger at the same time → trigger notification still fires; voice arbiter (F04) plays navigation instruction first, then the prompt.

#### Done when
Graph covers all POIs/facilities, connected; UI10/UI11 work on replay and on one real walk; reroute works; unit tests for Dijkstra, snapping, ETA, turn classification pass.

---

### F05 — Search & Destination
**Owner** B · **Sprint** S3 (PB13) · **Screens** UI09 · **Priority** Must

**Summary.** Search POIs and facilities by name (partial, case-insensitive, light typo tolerance), filter by category, sort by **walking** distance with distance + ETA, and open detail or start navigation.

#### Use cases
**UC-F05-1 Find a facility** — "toilet" → list of toilet facilities sorted by walking distance, each with "180 m · ±4 mnt"; tap → preview → *Navigasi* (F06).
**UC-F05-2 Find a POI by partial name** — "gua" → Gua Jepang, Gua Belanda (TC-07).
**UC-F05-3 Typo** — "gua blanda" / "tiolet" → still finds the item (D12).
**UC-F05-4 Filter by category** — chips: Semua · Sejarah · Alam/Flora-Fauna · Rekreasi/Wellness · Fasilitas. A chip shows only that category (AC2). Chips combine with the text query.
**UC-F05-5 No result** — "Tidak ditemukan untuk 'xyz'. Coba kategori:" + chips (AC5).
**UC-F05-6 No GPS / permission denied** — sorted alphabetically; distance column shows "—".

#### Matching algorithm (D12)
1. Normalize query and targets: lowercase, trim, collapse spaces, strip punctuation, map "goa"→"gua" via `keywords`.
2. Match each query token against item tokens (`name` + `keywords`): exact → prefix → substring → Levenshtein (≤1 for length 4–6, ≤2 for ≥7). Tokens < 4 chars: prefix/substring only.
3. Item matches if every query token matches something. Rank by match quality, then walking distance.
- Dataset is ~16 items → linear scan in memory, ≪1 s (AC4).

#### Acceptance criteria ↔ tests
TC-07 (offline: "gua", "toilet", random word, category filter). Unit tests: normalization, each typo case, filter, sort order with a stub `TrailRouter` returning fixed distances.

#### Done when
TC-07 passes in airplane mode; unit tests pass; result tap opens detail or navigation.

---

### A04 — Facility Finder
**Owner** B · **Sprint** S3 (with F05) · **Priority** Should

**Summary.** Facilities (toilet, musala, warung, pos petugas, istirahat) show as distinct Slate Post markers, are searchable via the "Fasilitas" filter and navigable, and **never** trigger notifications.

**Use cases:** UC-F05-1 covers search; on the map, tapping a facility marker shows name, distance, ETA, *Navigasi*. Hydration reminder (F08) references the nearest `istirahat` point.

**Verify:** A04 AC — facilities appear under "Fasilitas" and walking past one produces no notification (replay test that passes through FS01 coordinates; `TriggerEngine` never loads facilities — enforced by type).

---

### F03 — Multimodal Exploration (POI Detail)
**Owner** C · **Sprint** S2 (PB09) · **Screens** UI06 · **Priority** Must · **Content** non-coder (PB08)

**Summary.** Each POI shows 1–3 survey photos, an 80–150-word text with key facts, a 60–120 s team-recorded narration (TTS fallback when no recording), estimated visit time and a safety note — all offline.

#### Use cases
**UC-F03-1 Open POI Detail**
- *Entry points:* trigger notification *Lihat* (≤2 s), map marker preview, Search, Recommendation, QR, manual pick, UI11 *Buka detail*.
- *Layout (top → bottom):* photo gallery hero (swipe, 24dp radius); POI name (Fraunces) + category chip; meta row "±15 mnt kunjungan · 650 m · ±12 mnt jalan"; audio player (waveform scrubber, 72dp play/pause, ±10 s, elapsed/total mono); text; key facts list; safety note card (caves); *Navigasi ke sini* (if not here); source line in small text.
- *Postcondition:* publishes `PoiEngaged(poiId, opened)` → trigger marks it Visited (D05). Closing the screen publishes `PoiFinished(detailClosed)`.

**UC-F03-2 Listen** — play / pause / resume / replay (AC2); audio continues when leaving the screen or locking the phone (F04).
**UC-F03-3 Recording missing** — `audio: null` → player shows "Narasi suara sintetis" and `TtsService` reads `text`. Placeholders must be replaced by recordings before S5.
**UC-F03-4 Close detail** — closing triggers the recommendation (F07, ≤2 s).

#### Content rules (for the content owner)
- Text 80–150 words, Bahasa Indonesia, warm-formal, addresses "Anda".
- Every fact has a source in `sources` (manager, signboard, survey measurement). **No fact from AI alone** (PRD §8.2). Gua Jepang/Gua Belanda history needs the manager or signboard.
- Photos: own survey photos only (copyright), WebP, ≤1280 px long edge.
- Audio: 60–120 s, mono MP3 64 kbps, −16 LUFS, quiet room, same narrator for all POIs.

#### Implementation
Module `poi`. Pure UI over `ContentRepository` + `AudioService`. Images via `Image.asset` with pre-cached hero. Opening from a notification: notification payload = POI id → `go_router` route `/poi/:id`; app cold start must route directly (measure ≤2 s).

#### Acceptance criteria ↔ tests
TC-05 (10 POIs in airplane mode: text, ≥1 photo, audio). AC2 player controls; AC3 airplane mode; AC4 notification → detail ≤2 s (stopwatch, warm and cold start). `content_test.dart` checks every POI has text within 80–150 words, ≥1 existing image file, an existing audio file or explicit null.

#### Done when
10 POIs render offline with real photos; player controls work; open-from-notification ≤2 s on the slower test phone.

---

### F04 — Eyes-Free Interaction
**Owner** C (audio, TTS, lock screen) with A (notification actions) · **Sprint** S3 (PB11) · **Screens** UI07 · **Priority** Must

**Summary.** The visitor can explore with the phone in a pocket: vibration + sound when approaching, voice prompt on trigger, optional Auto-Play, notification actions and lock-screen/earphone media controls, voice navigation, and spoken reminders.

#### Use cases
**UC-F04-1 Pocket visit (TC-06)**
- *Precondition:* session active, screen locked, earphones in.
- *Flow:* 1) Approaching → phone vibrates once + short sound. 2) Trigger → voice: "Anda tiba di Gua Jepang. Ingin mendengar sejarahnya?" + notification on the lock screen. 3) Visitor taps *Dengarkan* on the lock-screen notification **or** presses the earphone play button → narration plays. 4) Pause/resume via earphone button or lock-screen media controls. 5) Narration ends → short voice "Selesai. Rekomendasi berikutnya: …" (F07, if available).
- *Postcondition:* POI visited (D05).

**UC-F04-2 Auto-Play** — setting on → after the voice prompt, narration starts automatically ≤3 s after the trigger (AC2); POI visited.
**UC-F04-3 Voice navigation** — turn and arrival instructions spoken (F06), AC3.
**UC-F04-4 Spoken reminders** — closing (A03) and hydration (F08) are spoken + notified.

#### Voice arbitration (`VoiceArbiter`, owner C)
Only one voice at a time. Priority: **safety (closing reminder) > navigation > trigger prompt > reminder (hydration)**. When a higher-priority utterance arrives during narration: **duck** narration to 20% for short utterances, or **pause** narration and resume after. Lower-priority utterances queue (drop if stale > 30 s). Requests audio focus; respects phone calls (pause on call).

#### Implementation
- `audio_service` provides the media session → lock-screen controls, earphone buttons, Bluetooth controls, and the foreground media notification. `just_audio` plays files.
- `flutter_tts` with `id-ID`. At startup check the Indonesian voice is installed **offline**; if not, onboarding prompts to install it, and critical prompts fall back to pre-recorded clips in `assets/audio/prompts/` (Risk R3).
- **Technical spike (S2, A + C, half a day):** making the *Dengarkan* notification action start playback **without opening the app**. Non-UI notification actions may run in a background isolate that can't reach the main-isolate audio service. Options: (a) action with UI that immediately backgrounds, (b) message the main isolate via `IsolateNameServer`/`SendPort`, (c) make the trigger notification itself a media-style notification owned by `audio_service`. Choose by end of S2 and record the decision.
- Vibration patterns: approaching = 1 × 300 ms; trigger = 2 × 200 ms.

#### Acceptance criteria ↔ tests
| AC (PRD F04) | Verify |
|---|---|
| (1) Locked phone in pocket: receive trigger, hear narration, pause/resume without opening app | TC-06 field + replay at desk |
| (2) Auto-Play starts ≤3 s after trigger | Replay + timestamp in log |
| (3) Voice instruction at every turn node of the test route | TC-08 |
| (4) ≥4/5 usability respondents complete a POI visit without looking | PB20 usability |

#### Done when
TC-06 passes on replay with the screen locked on both phones; spike decision recorded; arbiter unit tests (priority, duck, queue drop) pass.

---

### A05 — Data-Driven Content
**Owner** C (loader + validation), content owner (data) · **Sprint** S1–S2 (PB04) · **Priority** Should

**Summary.** POIs, facilities, routes, hours and tunable parameters come from JSON assets (§3). A content change requires no code change.

#### Use cases
**UC-A05-1 Update a POI text or radius** — content owner edits `pois.json`, runs `tools/validate_content.py`, opens a PR; app reflects it on the next build without code changes (A05 AC).
**UC-A05-2 Bad data** — validation fails in CI/tests (missing image, duplicate ID, radius outside 15–50, unknown route id, word count out of range, POI without sources) → PR blocked. At runtime, a malformed file shows an error screen in debug builds rather than crashing silently.

#### Implementation
`ContentRepository` loads all JSON at startup (≈ tens of KB, <100 ms), parses into immutable models, builds lookup maps (`byId`, `byQr`). Schema version field for future changes.

#### Done when
Changing one POI's radius and text in JSON changes app behaviour with zero Dart changes (demo for A05 AC); validation tests run in `flutter test`.

---

### F07 — Contextual Recommendation
**Owner** A · **Sprint** S4 (PB15) · **Screens** UI08 · **Priority** Must

**Summary.** After a POI visit, recommend the next POI: only unvisited POIs that can be walked to, visited, and walked back to the gate before closing − 15 min; ranked by walking distance, interest, active route and difficulty; 1 main + 2 alternatives with reasons; otherwise "Kembali ke gerbang".

#### Use cases
**UC-F07-1 Get the next suggestion**
- *Trigger:* user closes POI Detail, **or** narration finishes in eyes-free mode, **or** user exits r+15 of the last visited POI (whichever first; once per visited POI).
- *Flow:* ≤2 s later, UI08 bottom sheet: "Berikutnya: Gua Belanda — 650 m, ±12 mnt" + reason chips ("Terdekat · Sesuai minat Sejarah · Ada di rute Santai") + 2 alternatives + *Navigasi* (one tap → F06, AC5). Screen off → silent notification + short voice line.
- *Postcondition:* recommendation logged (for TC-09 evidence).

**UC-F07-2 Not enough time** — no candidate passes the filter → sheet shows "Waktu tidak cukup untuk objek lain. Kembali ke gerbang — ±25 mnt" with *Navigasi ke gerbang* (TC-10 at 15.30).
**UC-F07-3 All POIs visited** — "Semua objek sudah Anda kunjungi" + *Kembali ke gerbang* + *Akhiri Jelajah*.
**UC-F07-4 Interests changed** — changing interests on Home/Settings re-ranks the next recommendation (AC4).
**UC-F07-5 On demand** — "Ke mana selanjutnya?" button on Explore runs the same algorithm any time.

#### Algorithm
```
now      = clock.now()
close    = park.hours.close (today)
budget   = (close − now) − closing_buffer(15 min)
pos      = locationService.last (good fix) else node of lastVisitedPoi
candidates = pois where
     id ∉ sessionLog.visitedPoiIds                      // D05: "Nanti" POIs stay candidates
     and id ≠ gate POI
     and (id ≠ P11 or activeRoute == trekking)
     and router.walkingTime(pos, poi) + poi.visit_minutes + router.walkingTimeBetween(poi, gate) ≤ budget
if candidates empty → BackToGate(router.walkingTime(pos, gate))
for c in candidates:
     dist       = 1 − walkingDistance(c) / max(walkingDistance over candidates)      // 0..1, nearest = 1
     interest   = 1 if c.category ∈ user.interests else 0
     route      = 1 if activeRoute != null and c.id ∈ activeRoute.poi_sequence else 0
     difficulty = 1 if c.difficulty ≤ activeRoute.difficulty (or 1 if no route) else 0
     score = 0.50·dist + 0.25·interest + 0.15·route + 0.10·difficulty            // D10, weights in park.json
sort by score desc, tie → shorter walk
return main = top1, alternatives = top2..3, reasons = factors with value 1 (+ "Terdekat" if dist == 1)
```

#### Acceptance criteria ↔ tests
| AC (PRD F07) | Verify |
|---|---|
| (1) Always an unvisited POI | TC-09 + unit test over random visit sets |
| (2) Shown ≤2 s after finishing a POI | Timestamp in log |
| (3) Nothing finishing after close − 15; at 15.30 → back to gate | TC-10 with `FakeClock` **and a fixed tester position** (D13) |
| (4) Changing interests changes order | Unit test with fixed distances: interest "Alam" vs "Sejarah" swaps top1 |
| (5) One tap to navigate | UI test |

**TC-10 fixture (D13):** position fixed at a named surveyed POI (e.g., P06), `FakeClock` set to 15.30, hours 08.00–16.00 → expected: BackToGate. The expected closing-reminder time = 16.00 − walk(P06→gate) − 15 min, computed from the real graph and written into the test script once the survey data exists.

#### Done when
Unit tests for filter, scoring, back-to-gate, interest re-rank pass; TC-09/TC-10 pass on replay + fake clock.

---

### A03 — Closing-Time Reminder
**Owner** A · **Sprint** S4 (PB17, closing part) · **Screens** UI13 (closing) · **Priority** Should

**Summary.** Continuously compute walking time to the gate and remind the visitor (voice + notification, with *Navigasi ke gerbang*) when `now ≥ close − walk_to_gate − 15 min`.

#### Use cases
**UC-A03-1 Reminder fires**
- *Flow:* Every 60 s during a session (and on every 50 m moved), compute `threshold = close − walkingTime(pos, gate) − 15 min`. When `now ≥ threshold` → voice (priority safety): "Kawasan tutup pukul 16.00. Waktu jalan ke gerbang ±25 menit." + high-priority notification + UI13 card with *Navigasi ke gerbang*. Fires **once** per session.
- *Example:* walk to gate 25 min, close 16.00 → fires at **15.20** (not 14.45 — see D13).

**UC-A03-2 Final call** (PROPOSED, optional) — if the visitor is still > 200 m from the gate at `close − walk_to_gate`, a second, stronger reminder: "Segera menuju gerbang sekarang."
**UC-A03-3 Session started late** — threshold already passed at session start → remind immediately, and Home's route chooser shows which routes no longer fit (F08).

#### Implementation
`ClosingReminder` subscribes to `Clock` ticks + `LocationService.fixes`; uses `TrailRouter.walkingTime(pos, gateNode)`. Hours from `park.json` (marked `verified: false` until the PM confirms — Lampiran B #4). Unit-tested with `FakeClock`.

#### Verify
TC-10 (fake clock, fixed position) — reminder fires at the computed minute, not ±1 min off. Unit tests: fires once, fires immediately when late, threshold moves as position changes.

---

### F08 — Wellness Trail Explorer
**Owner** C · **Sprint** S4 (PB16, PB17 hydration, PB18) · **Screens** UI02 route chooser, UI03 stats strip, UI13 hydration, UI14 summary · **Priority** Must

**Summary.** The domain innovation: three graded trails (Santai / Sedang / Trekking) with distance, elevation gain, duration and POIs; activity tracking (steps, GPS distance, duration, estimated calories); rest/facility markers; periodic hydration/rest reminders; session summary; flora-fauna content on nature POIs.

#### Use cases
**UC-F08-1 Choose a route (UI02)**
- *Flow:* Stacked route cards: name, difficulty badge, distance, ascent, ±duration, elevation sparkline, POI list. Each card shows **feasibility**: "Selesai sebelum 16.00" (green) or "Tidak cukup waktu hari ini" (clay red) computed as `now + duration ≤ close − 15`. Option "Tanpa rute (bebas)" too.
- *Postcondition:* active route stored; route line drawn on Explore; recommendation (F07) uses it; P11 enabled only for Trekking.

**UC-F08-2 Track activity**
- *Flow:* *Mulai Jelajah* → steps baseline taken from the step-counter sensor; Explore stats strip shows **langkah · jarak · durasi · POI x/10**, updating live.
- *Steps:* Android Step Counter sensor (cumulative since boot) − baseline at session start. Requires `ACTIVITY_RECOGNITION` (Android 10+).
- *Distance:* sum of haversine between consecutive accepted fixes, only when accuracy ≤ 20 m and the move > max(3 m, accuracy/2) — prevents jitter from inflating distance while standing.
- *Duration:* session wall time; also "active time" (minutes with steps).
- *Calories (D11):* `kcal = MET × weight_kg × hours`, MET 3.5 on flat/gentle segments, 6.0 on segments with grade > 8% (from graph ascent); weight from Settings, default 60 kg; always labelled "estimasi".

**UC-F08-3 Hydration/rest reminder (UI13)**
- *Flow:* every N min of session time (default 45, Settings: 30/45/60/off) → voice + notification "Sudah 45 menit berjalan. Saatnya minum air. Titik istirahat terdekat: Bangku Hutan Pinus, 120 m." with *Navigasi*. Snooze 10 min. Timer resets when the user dismisses or reaches a rest point.

**UC-F08-4 End session (UI14)**
- *Flow:* *Akhiri Jelajah* (Explore or at gate) → confirm → summary: POIs **visited** x/10 (+ "dilewati" count for triggered-not-visited, D05), steps, distance, duration, kcal estimate, list of unvisited POIs "untuk kunjungan berikutnya". Data saved locally only (AC5). Foreground service stops.

**UC-F08-5 Learn about flora/fauna** — nature POIs (P07, P08, P10) carry flora-fauna content via F03; no separate screen needed.

#### Acceptance criteria ↔ tests
| AC (PRD F08) | Verify |
|---|---|
| (1) 3 routes with distance, elevation, duration, difficulty | TC-11 (data from survey, `[VERIFIKASI]` until then) |
| (2) Steps vs manual count ≤10% over 200 steps | TC-12 on both phones, phone in pocket and in hand |
| (3) Hydration reminder (voice + notification) at the set interval | `FakeClock` unit test + device check with 1-min debug interval |
| (4) Summary matches session log | Compare UI14 with `visit_events` / `sessions` rows |
| (5) Activity data only on device | No network permission use; code review |

#### Edge cases
- Phone without step-counter sensor → hide steps, show distance only, note in summary; record test phone models (Risk R4).
- Sensor counter resets on reboot mid-session → detect negative delta, re-baseline, keep accumulated steps.
- App killed mid-session → session restored from SQLite on reopen with "Lanjutkan jelajah?".

#### Done when
TC-11/TC-12 pass; hydration fires on fake clock; summary numbers equal DB values; session survives app restart.

---

### A07 — Accessibility
**Owner** C · **Sprint** S4–S5 · **Priority** Could

- Text scaling up to 200% without clipping (test UI06, UI09, UI10 at max font).
- Contrast ≥4.5:1 for text. **Fix PROGRESS #19:** Trail Green `#3E8A5B` on white is 4.21:1 — use a darker shade (~`#357A4F`) for text, keep `#3E8A5B` for non-text indicators only.
- Touch targets ≥48 dp; `Semantics` labels on all icon buttons (play, skip, QR, recenter, navigasi); status chips announce changes ("GPS lemah").
- Verify with Android Accessibility Scanner on main screens: no critical issues (A07 AC).

---

### App shell — Onboarding (UI01), Home (UI02), Session lifecycle, Settings (UI15)
**Owner** C (screens), A (session controller) · **Sprint** S3 (Onboarding/Home), S4 (Settings)

**UC-SH-1 First launch (UI01).** 3 short pages (what the app does, eyes-free with earphones, offline) → permission requests **in context, one at a time**, each with a one-line reason: location → notifications → physical activity → (camera only when the QR scanner is first opened) → battery-optimization exemption prompt (Risk R2) → offline Indonesian TTS voice check (Risk R3). Denials are allowed; the app explains the degraded mode.

**UC-SH-2 Home (UI02).** Greeting (Fraunces), interest chips (Sejarah, Alam/Flora-Fauna, Rekreasi/Wellness), route chooser (F08), today's hours "08.00–16.00" with time remaining, P01 banner when at the gate (D07), primary button **Mulai Jelajah**.

**UC-SH-3 Start session.** `SessionController.start()`: create `sessions` row → `LocationService.startSession()` (foreground service) → `TriggerEngine.reset()` → pedometer baseline → start reminders → navigate to Explore.

**UC-SH-4 End session.** stop reminders → stop location service → final metrics → UI14 summary.

**UC-SH-5 Settings (UI15).** Auto-Play (default off), voice navigation on/off, hydration interval, text size, body weight (optional, on-device), content/version info ("Data offline: tersedia · versi 1"), debug menu hidden behind 7 taps on the version (debug builds only).

---

## 6. Cross-cutting concerns

### 6.1 Android permissions
| Permission | When requested | If denied |
|---|---|---|
| `ACCESS_FINE_LOCATION` | Onboarding | QR + manual mode; no dot; search by name |
| `POST_NOTIFICATIONS` (13+) | Onboarding | In-app banners + voice only; lock-screen actions unavailable |
| `ACTIVITY_RECOGNITION` (10+) | Onboarding | No steps; distance + duration only |
| `CAMERA` | First QR scan | Manual pick only |
| `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_LOCATION`, `FOREGROUND_SERVICE_MEDIA_PLAYBACK` | Manifest (no prompt) | — |
| Battery optimization exemption | Onboarding (explained) | Screen-off tracking may be killed on some phones |

### 6.2 Notification channels
| Channel | Importance | Used by |
|---|---|---|
| `session` | low, ongoing | foreground service "sedang memandu" |
| `trigger` | high, sound | F02 trigger with actions |
| `reminder` | high, sound | A03 closing, F08 hydration |
| `recommendation` | default, silent | F07 when screen off |
| media | (audio_service) | narration controls |

### 6.3 Timing budget (from PRD ACs)
Position ≤10 s · trigger notification ≤10 s after entry · QR ≤3 s · POI Detail from notification ≤2 s · Auto-Play ≤3 s · route ≤3 s · reroute ≤5 s · search ≤1 s · recommendation ≤2 s.

### 6.4 Logging
Every location fix (session only), trigger event, recommendation, reminder and navigation start/arrival goes to SQLite with timestamp. A debug "Export log" button writes CSV to Downloads for the QA testing report. No data leaves the device (NG05).

### 6.5 Debug tooling (debug builds only) — build this first, it saves days
- **GPX replay:** pick a track from `test_data/gpx/`, speed ×1/×5/×20, optional accuracy override (to simulate canopy).
- **Fake clock:** set "now" (e.g., 15.30) and speed; all reminders and recommendations use it (TC-10).
- **Debug overlay on Explore:** per-POI distance + state + debounce count, current accuracy, active interval.
- **Teleport:** long-press the map to inject a fix there.

---

## 7. Testing strategy & TC mapping

| Level | What | Who | When |
|---|---|---|---|
| Unit | TriggerEngine, Dijkstra/ETA/snapping/turns, Search matching, Recommender, ClosingReminder, Hydration timer, VoiceArbiter, content validation | Owning coder | With every PR |
| Desk integration | GPX replay + fake clock on a real phone, screen locked | Owning coder + QA | End of each sprint |
| Field | TC-01…TC-13 at Tahura | QA + all | S5 (pilot run of TC-01/02 in S3 if a survey trip happens) |
| Usability | ≥5 respondents, task-based + SUS ≥68 | QA + Design | S5 (PB20) |

| TC | Feature | Desk-testable first? | Owner of the fix |
|---|---|---|---|
| TC-01 | F01 | Partly (replay) | A |
| TC-02 | F02 | Yes (replay) | A |
| TC-03 | F02 | Yes (unit + replay) | A |
| TC-04 | F02, A02 | Yes (printed QR) | A |
| TC-05 | F03 | Yes | C |
| TC-06 | F04 | Yes (replay, locked) | C + A |
| TC-07 | F05 | Yes | B |
| TC-08 | F06 | Partly (replay detour) | B |
| TC-09 | F07 | Yes (replay) | A |
| TC-10 | F07, A03 | Yes (fake clock + fixed position) | A |
| TC-11 | F08 | Yes (needs survey data) | C |
| TC-12 | F08 | Field (200 steps anywhere) | C |
| TC-13 | A01 | Field | All |

---

## 8. W12 Major Progress Review demo script

Sprint 3 goal: Start → Explore → Trigger → Information → Search → Navigation, including eyes-free. Run it on a phone with **GPX replay** (backup: recorded video of a real walk).

1. **Start** — Onboarding permissions → Home: pick interests + route → *Mulai Jelajah*. (C, A)
2. **Explore** — offline map in airplane mode, user dot moving along the replay track, geofence rings. (B, A)
3. **Approaching** — buzz + UI04 banner with live distance. (A)
4. **Trigger, eyes-free** — lock the phone; voice prompt; tap *Dengarkan* on the lock screen; pause/resume with earphones. (A, C)
5. **Information** — unlock, open POI Detail: photos, text, facts, player. (C)
6. **QR fallback** — scan the printed Gua Jepang QR in airplane mode. (A)
7. **Search** — type "toilet" → sorted by walking distance. (B)
8. **Navigation** — *Navigasi* → route on the trail, ETA, voice instruction at a junction, deliberate detour → reroute, arrival. (B)

Report items (PRD §7 W12 table): planned PB06–PB14, done/not done, evidence links (video, APK, unit test output, `visit_events` export), blockers and recovery plan. Recommendation and Wellness are **S4 scope** — say so explicitly instead of half-demoing them.

---

## 9. Risks

| ID | Risk | Impact | Mitigation | Owner |
|---|---|---|---|---|
| R1 | Survey data (coordinates, GPX, photos) late or incomplete | Blocks real radii, graph, routes, TC-11 | Build on placeholder data with the real schema; survey trip date fixed by PM; replay tracks recorded on the same trip | Content + PM |
| R2 | OEM battery managers kill the foreground service with the screen off | Triggers missed in pocket mode (TC-06 fail) | Battery-optimization exemption in onboarding; test on both team phones' brands early (S2); document per-brand steps | A |
| R3 | Indonesian TTS voice not installed offline | No voice prompts/navigation offline | Startup check + install prompt; pre-recorded clips for fixed prompts; recorded narration for all POIs | C |
| R4 | Test phone lacks a step-counter sensor | TC-12 impossible on that phone | Check sensors on all team phones this week; pick test devices accordingly | C |
| R5 | GPS under canopy/valley worse than 30 m for long stretches | Few triggers in forest sections | Calibrate radii in S5; QR boards at weak spots; GPS-weak banner (D08) | A + QA |
| R6 | Tile licensing (OSM bulk download banned) | Offline map not legally packageable | Render own tiles from OSM data; attribution | B |
| R7 | Rainy season (late Nov) during field tests | Field tests postponed | Do desk tests first; schedule field days early in S5 with a backup date | PM + QA |
| R8 | Notification "Dengarkan" can't start audio without opening the app | F04 AC1 fails | S2 spike, three fallback options (F04) | A + C |
| R9 | One coder blocked on another's module | Schedule slip before W12 | Day-1 contracts + stubs; integration owner (A) merges daily | All |
| R10 | Every requirement is "Must", no descoping order | No graceful plan if late | PROPOSED cut order if S4 slips: A06 → A07 → F07 alternatives/reasons → calorie estimate → final-call reminder. Never cut F01–F06, A01, A02. | PM |
