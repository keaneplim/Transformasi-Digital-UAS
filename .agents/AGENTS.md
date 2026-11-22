# AGENTS.md — Jelajah Taman (Kelompok 5)

Document status: Active
Purpose: complete, stable project context for AI coding agents (Claude Code, Codex, others). Read this instead of re-parsing the binaries. Requirements themselves live in the PRD: [`docs/prd/PRD.md`](../docs/prd/PRD.md) (generated from the canonical docx); this file summarizes and points to it, and the PRD wins on any conflict.

## 0. The `.agents/` folder

| File | Role | Changes |
|---|---|---|
| `AGENTS.md` | This file: project, team, requirements summary, architecture, data, design, testing, file map. | When scope, structure or file layout changes |
| `rules.md` | How agents work here: read order, sources of truth, PRD sync rule, verification, git, copy rules, end-of-session updates, ADR rules. | Rarely |
| `MEMORY.md` | Session handoff: where the work stands now, open threads, next steps, newest session first. | Every session |
| `PROGRESS.md` | Project status: sprint timeline, open questions, known issues #1–#n, team decisions, change log. | Every session that changes status |

Machine-specific paths and tools (Flutter location, Python packages, local signing) live in the uncommitted root `CLAUDE.local.md` on each laptop. The root `CLAUDE.md` only points here.

---

## 1. Project

- **Course:** Tugas Besar **Transformasi Digital**, Prof. Ir. Kridanto Surendro, STI ITB, 2026. **Topik 7: Public Park & Wellness Explorer.**
- **Product:** **Jelajah Taman**, an Android app (Flutter) that guides visitors through **Tahura Ir. H. Djuanda, zona Dago Pakar** (gerbang Dago Pakar → area Gua Belanda–Gua Jepang): offline POI map, automatic GPS geofence triggers (QR fallback in the caves), audio narration usable eyes-free, search and trail navigation, next-POI recommendations that respect closing time, and a Wellness Trail mode.
- **Problem (PRD §1.1):** physical signage is sparse and thin on history/nature content; first-time visitors ask staff, take wrong trails, can't estimate time to the next object or back to the gate, and cellular signal is unreliable in the forest.
- **Users (PRD §1.2):** first-time visitors, families with children, students on educational visits, hikers/wellness regulars; stakeholders are the park manager (UPTD Tahura, Dinas Kehutanan Jabar) and field staff. No admin/CMS features (NG04): the manager's needs are met by structured JSON content.
- **Goals G01–G06 (PRD §1.4):** automatic location-based POI info · find and reach POIs offline · eyes-free exploration · more objects visited via realistic recommendations · wellness (route by ability, activity tracking) · safety (closing reminder, facilities).
- **Non-goals NG01–NG08:** no ticketing/payment · only zona Dago Pakar · no AR/BLE/computer vision · no CMS · no accounts, login, social or server-side personal data · not an SOS tool, no tracking by the manager · no bookings/transactions · Bahasa Indonesia only.
- **Language:** deliverables and all visitor-facing copy in **Bahasa Indonesia** (formal-academic for documents, "Anda" in the UI). Engineering docs, ADRs and code comments in English.

### Team

| Member | NIM | Course role | Build role | Presents slides |
|---|---|---|---|---|
| Jacob Reinhard Marudut Siagian | 18223026 | PM / Scrum Master | — | 1, 2, 12, 15 |
| Keane Putra Lim | 18223056 | Business Analyst | Coder B + integrator | 3, 4, 5 |
| Michael Dimas Sarono | 18223076 | UX/UI Designer | — (hi-fi design, test scenarios) | 6, 11 |
| Michael Ballard Silaen | 18223080 | Developer | Coder A | 8, 9, 10, 13 |
| M Khalfani Shaquille Indrajaya | 18223104 | QA (+ AI disclosure log) | Coder C | 7, 14 |

Module ownership per coder: §5.3 below, `docs/engineering/ARCHITECTURE.md` §3 and `IMPLEMENTATION_PLAN.md` §0.1. Ownership means the owner reviews changes, not that others may not touch the module.

### Timeline (PRD §7; live status in `PROGRESS.md`)

| Sprint | Week | Dates (2026) | Backlog |
|---|---|---|---|
| S1 fondasi & location awareness | W10 | 26 Okt – 1 Nov | PB01–PB05 |
| S2 POI & trigger logic | W11 | 2 – 8 Nov | PB06–PB10 |
| S3 core flow & eyes-free | W12 | 9 – 15 Nov (major progress review) | PB11–PB14 |
| S4 recommendation & wellness (**feature freeze** end of W13) | W13 | 16 – 22 Nov | PB15–PB18 |
| S5 field test, usability, fixes | W14 | 23 – 29 Nov | PB19–PB21 |
| Final deliverables | W15 | — | APK, Testing Report, PRD Compliance Matrix, video ≤3 min, AI & Tools Disclosure |

---

## 2. Requirements summary (PRD v0.9.2)

Full text, acceptance criteria and priorities: PRD §3 and §3.1. Test cases: PRD Lampiran A. Accepted implementation decisions D01–D14 are already in the PRD (v0.9.1); v0.9.2 changed the narration (F03).

### Core requirements (all Must)

| ID | Requirement | Key parameters | Tests |
|---|---|---|---|
| F01 | Location Awareness | High-accuracy GPS every ±3 s with **distance filter 0** (D14); blue dot + accuracy ring on the offline map; accuracy >30 m = "GPS lemah", not used for triggers; keeps reading with the screen off during a session (foreground service). | TC-01 |
| F02 | Location-Based Trigger | Haversine distance to **every eligible POI** each reading (D01); states and thresholds in §3. Approaching vibration once per approach (D02); "Nanti" does not mark visited (D05). GPS weak for 60 s → QR / manual pick banner (D08). | TC-02, TC-03, TC-04 |
| F03 | Multimodal Exploration | Per POI: 1–3 survey photos, text 80–150 words + key facts, **narration 120–180 s** (Gemini TTS from the team's sourced scripts, verified with Speech-to-Text; device TTS fallback), visit-time estimate. All local. | TC-05 |
| F04 | Eyes-Free Interaction | Approach vibration + sound, voice prompt on trigger, Auto-Play option, notification actions + lock-screen/earphone media controls, voice turn instructions and arrival, closing/hydration reminders by voice. | TC-06 |
| F05 | Search & Destination | POIs + facilities by name: partial, case-insensitive, typo tolerance Levenshtein ≤1 (4–6 letters) / ≤2 (≥7), synonym list ("wc" → toilet) (D12); category filter (Sejarah, Alam/Flora-Fauna, Rekreasi/Wellness, Fasilitas); sorted by walking distance with distance + ETA. | TC-07 |
| F06 | Navigation | Trail graph (nodes = junctions/POIs, edges with length + ascent), Dijkstra, route line, remaining distance, ETA = 3 km/h + 1 min per 10 m ascent (D09), voice at junctions; arrived ≤15 m (never re-triggers, offers "Buka detail", D06); off-route >30 m → reroute. | TC-08 |
| F07 | Contextual Recommendation | After finishing a POI: candidates = unvisited POIs, kept if walk to POI + visit time + walk POI→gate ≤ time to close − 15 min; score `0.50·distance + 0.25·interest + 0.15·active route + 0.10·difficulty` (D10, weights in data); 1 main + 2 alternatives with reasons; none left → "Kembali ke gerbang". | TC-09, TC-10 |
| F08 | **Wellness Trail Explorer** (domain innovation) | 3 routes Santai/Sedang/Trekking with distance, ascent, duration, POIs; steps (pedometer), distance (GPS), duration, kcal = MET × weight × duration (optional on-device weight, default 60 kg, "estimasi", D11); rest/facility markers; hydration reminder every 45 min (adjustable); session summary. | TC-11, TC-12 |

### Additional requirements

| ID | Requirement | Priority | Key point | Tests |
|---|---|---|---|---|
| A01 | Offline Mode | Must | Map, POI data, photos, audio, graph bundled; F01–F08 work in airplane mode. | TC-13 |
| A02 | QR Fallback Trigger | Must | QR at cave mouths/weak-GPS spots, payload `jelajahtaman://poi/P05`; opens the right POI ≤3 s offline; unknown QR → error message. | TC-04 |
| A03 | Closing-Time Reminder | Should | Fires at **jam tutup − walk-to-gate − 15 min** (the formula is authoritative, D13) with navigation to the gate; hours are data. | TC-10 |
| A04 | Facility Finder | Should | Facilities are markers, searchable and navigable, **never trigger**. | — |
| A05 | Data-Driven Content | Should | POIs, routes, hours in JSON; content changes need no code change. | — |
| A06 | Battery-Aware Tracking | Could | Sparser GPS when stationary; ≤15% battery per hour. | — |
| A07 | Accessibility | Could | Larger text, contrast, targets ≥48 dp, screen-reader labels. | — |

### Acceptance bar
- Field tests TC-01…TC-13 (PRD Lampiran A); test scenarios SK-* in `docs/qa/scenario/` trace to every AC and TC.
- Usability: ≥5 respondents, task-based + SUS, **SUS ≥68** (PB20).
- Pedometer error ≤10% over 200 manually counted steps (TC-12).
- Final compliance matrix: PRD §11 (filled in W14–15). Unresolved items before baseline v1.0: PRD Lampiran B.

---

## 3. Location-trigger logic (PRD §4.2, decisions D01–D08, D14)

- **Readings:** every ±3 s, distance filter 0; discard accuracy >30 m (GPS lemah); glitch filter on implausible jumps.
- **States per POI:** `Outside → Approaching → Triggered → Visited → Cooldown`.
  - Approaching: enter at ≤ r+30 m, exit back to Outside only at > r+40 m (hysteresis, D03); vibrate + sound once per approach episode, only for eligible POIs (D02).
  - Triggered: ≤ r on **2 consecutive** readings. Among several qualifying POIs, the nearest triggers (D01).
  - Visited: user chose *Dengarkan* or *Lihat*, Auto-Play started, POI Detail opened by any route, or QR scan. *Nanti* leaves it triggered-not-visited (D05), so it stays a recommendation candidate.
  - Re-trigger only when **both**: user was > r+15 m at least once since the trigger **and** ≥10 min since the trigger time (D04).
- **Fallback layers:** GPS → QR scan (jumps straight to Triggered/Visited) → manual POI pick. GPS weak for 60 s → UI12 banner *Pindai QR* / *Pilih manual* (D08).
- **P01 (gate)** is not handled by the trigger engine: Home offers to start a session when a fix is inside P01 (D07).
- **Navigation arrival** never creates a trigger (D06).

### POIs (PRD §4.1) — id · name · radius (m)

P01 Gerbang 30 · P02 Monumen 25 · P03 Museum 25 · P04 Kolam Pakar 30 · P05 Gua Jepang 20 + QR · P06 Gua Belanda 20 + QR · P07 Penangkaran Rusa 30 · P08 Hutan Pinus 40 · P09 Area Piknik 40 · P10 Koleksi Flora 25 · P11 Curug Omas 40 (optional, Trekking only; possibly outside the zone, PROGRESS #13).

**Facilities** FS01–FS05 (toilet, musala, warung, pos petugas, istirahat) never trigger. Content also has FS06–FS10 from the 7 Nov survey (toilet + musala near Gua Belanda, saung/gazebo rest points), not yet in the PRD (PROGRESS #25).

**Routes [VERIFIKASI]:** Santai 2,5 km ±2 j · Sedang 4 km ±3 j · Trekking 6 km ±4 j (graph-derived values differ, PROGRESS #27). **Hours:** ±08.00–16.00 [VERIFIKASI].

---

## 4. Screens (PRD §5.1 ↔ code)

| ID | Screen / state | Requirements |
|---|---|---|
| UI01 | Onboarding & permissions (location, notifications, physical activity, camera) — opens on a full-screen welcome with Pako | F01, F04, F08 |
| UI02 | Home — choose interests and route | F07, F08 |
| UI03 | Explore map | F01, F08, A01 |
| UI04 | Approaching banner | F02, F04 |
| UI05 | POI trigger card/notification (*Dengarkan / Lihat / Nanti*) | F02, F04 |
| UI06 | POI Detail (photos, text, key facts, player, visit time) | F03, F04 |
| UI07 | Eyes-free / lock screen | F04 |
| UI08 | Recommendation sheet (1 + 2) | F07 |
| UI09 | Search & facility filter | F05, A04 |
| UI10 | Navigation | F06, F04 |
| UI11 | Arrived | F06 |
| UI12 | GPS weak / QR scanner / manual pick | F02, A02 |
| UI13 | Closing & hydration reminder | A03, F08 |
| UI14 | Session summary | F08 |
| UI15 | Settings (Auto-Play, hydration interval, text size, Mode demo panel) | F04, F08, A01, A07 |

All screens currently live in `lib/modules/shell/src/ui/` and are driven by `GuideController` (`lib/modules/shell/src/state/`, ADR 0009); they move to their owner modules as the engines land. Tab changes Beranda · Peta · Cari are choreographed by `TabStage` (`tab_stage.dart`, DESIGN.md §6): wrap new pieces on those pages in `Staged`.

---

## 5. Architecture (`docs/engineering/ARCHITECTURE.md`, ADRs 0001–0009)

### 5.1 Shape
**Modular monolith**: one Flutter app, one build, modules as folders under `lib/modules/<m>/` with a public front door `<m>.dart` and private `src/{domain,data,application,ui}`. Boundaries are enforced by `tools/check_architecture.dart` in CI. Riverpod without code generation; hand-written models; in-process `EventBus` for ~10 domain events; Open/Closed only at listed extension points (`ScoreFactor`, `Reminder`, location sources).

### 5.2 Rules R1–R8 (ARCHITECTURE §2)
1. **R1** Import other modules only through `lib/modules/<m>/<m>.dart`.
2. **R2** Dependencies point to lower levels only; no same-level imports, no cycles.
3. **R3** Questions = calls, news = events.
4. **R4** `src/domain/` is pure Dart (no Flutter, no plugins).
5. **R5** A plugin is imported only in `src/data/` (UI plugins in `src/ui/`) of the one module that owns it.
6. **R6** Each module owns its tables and SharedPreferences keys.
7. **R7** Time only from `Clock` (`core/clock`), never `DateTime.now()`.
8. **R8** Implementations are bound in the composition root (`modules/shell/src/app/`).

R1, R2, R5, R7 are checked mechanically.

### 5.3 Modules

"Owns" lists the plugin each module is meant to own (R5), including plugins not yet added (§9).

| Level | Module | Owner | Responsibility | Owns |
|---|---|---|---|---|
| 0 | `core` | A (+all) | `Clock`, geo maths, `EventBus` + events, storage handle, logging, `Result`, theme tokens `JT`/`JTText`, UI kit `core/ui` (components, Pako, doodles, motion, `SceneImage`) | `shared_preferences` |
| 1 | `content` | C | Load/validate JSON assets; immutable models | assets |
| 1 | `location` | A | GPS fixes, quality, compass, permission access, foreground tracking, GPX replay | `geolocator`, `flutter_compass` |
| 1 | `audio` | C | Narration, TTS, `VoiceArbiter`, media session | `just_audio`, `audio_service`, `flutter_tts` |
| 1 | `notify` | C | Channels, posting, action callbacks, vibration | `flutter_local_notifications`, `vibration` |
| 2 | `routing` | B | Graph, snapping, Dijkstra, ETA, turn instructions, `TimeBudget` | — |
| 2 | `trigger` | A | `GeofenceEngine` state machine, QR + manual triggers, QR scanner | `mobile_scanner` |
| 3 | `session` | A | Session lifecycle, visit log, restore after kill | session keys |
| 3 | `map` | B | Explore map on the bundled vector basemap (ADR 0008) + optional satellite | `flutter_map`, `latlong2` |
| 3 | `navigation` | B | Active navigation, reroute, arrival | — |
| 3 | `poi` | C | POI Detail, gallery, player widget | — |
| 4 | `search` | A | Matching, facility finder, UI09 | — |
| 4 | `recommendation` | A | Candidate filter, `ScoreFactor` scoring, UI08 | — |
| 4 | `reminders` | B (scheduler, closing) / C (hydration) | `ReminderScheduler`, `Reminder` implementations, UI13 | — |
| 4 | `wellness` | C | Routes data, pedometer, distance/kcal, summary data | `pedometer` |
| 5 | `shell` | C / B / A | App entry, composition root, go_router, onboarding, Home, Explore, summary, Settings, debug menu; temporarily all screens + `GuideController` | `go_router`, `permission_handler` |

### 5.4 Events E1–E10 (ARCHITECTURE §5.2; IDs and primitives only)
E1 `SessionStarted` · E2 `SessionEnded` · E3 `PoiApproached` · E4 `PoiTriggered` · E5 `PoiEngaged` · E6 `PoiVisited` · E7 `PoiFinished` · E8 `NavigationStarted` · E9 `NavigationArrived` (never consumed by `trigger`) · E10 `ReminderDue`. Adding an event means adding a row to the catalogue in the same change. GPS fixes are streams, not events.

### 5.5 Runtime
- **Two position sources** behind one `GuideController` (ADR 0009): real (default, GPS) and demo (simulated walk, Settings → Mode demo, persisted as `app_mode`). Both feed the same `GeofenceEngine`.
- One foreground service (location) + the `audio_service` media service; no WorkManager; notification actions bridged from their own engine via `IsolateNameServer`.
- Session state persisted in `KeyValueStore` (`session.current` / `session.last`); an unfinished same-day session is restored after the app is killed.
- All tunables in `park.json` (`ParkConfig`); no magic numbers in domain code.

---

## 6. Content and data pipeline

| File (`assets/content/`) | Holds | Produced by |
|---|---|---|
| `pois.json` | POIs: coordinates, radius, texts, photos, audio, visit time, `coord_source`/`coord_ref` | `tools/make_dummy_data.py` + `tools/resolve_coords.py` + `tools/narration.py` fields |
| `facilities.json` | FS01–FS10 | same |
| `routes.json` | Santai / Sedang / Trekking | same |
| `park.json` | Hours and every tunable parameter | hand-edited |
| `trail_graph.json` | Nodes/edges with length + ascent | `tools/osm_to_graph.py` (current, from OSM) or `tools/gpx_to_graph.py` (survey GPX) |
| `image_credits.json` | Credit for every image | `tools/photos.py`; checked by the validator |

- `assets/map/basemap.json` + `hillshade.png`: offline vector basemap generated by `tools/osm_to_basemap.py` (ADR 0008).
- Narration: scripts `docs/content/narration/P01–P11.md` → `tools/narration.py` (Gemini TTS, STT verification, loudness) → audio assets; unchanged scripts skipped via `manifest.json`.
- `tools/validate_content.py` validates all content in CI.
- Content is **DUMMY or ESTIMATE** where survey/manager data is missing: every coordinate carries `coord_source` (SURVEY_EXIF / OSM / GMAPS / ESTIMATE); ESTIMATE = `[VERIFIKASI]` on site. POI texts are `[ISI]` until sourced facts exist. Raw survey data in `survey/raw/` (photos on the team Drive).

---

## 7. Design system (`docs/design/DESIGN.md`, ADR 0012)

v2 **"Sunlit Field Guide"**: cream page, sun-yellow header band with drifting doodles and a scalloped canopy edge, forest-green primary actions, terracotta only for closing time/destructive actions, sky-blue visitor dot. Fonts **Bricolage Grotesque** (display, numbers with tabular figures) and **Plus Jakarta Sans** (UI/body), both bundled. Mascot **Pako** (pinecone with a leaf sprout) changes pose with the situation. Tokens: `JT` / `JTText` in `lib/core/theme/app_theme.dart`; widgets in `lib/core/ui/`. Copy rules in DESIGN.md §8. Visual baselines: `test_goldens/baselines/*.png` (390×844 and 360×780). Confirmed by the team as the official design on 2026-11-22; v1 is archived.

---

## 8. Testing, CI and release

- **Unit/widget tests** in `test/` mirror `lib/`; domain logic is tested without a device. Required suites: trigger engine, routing (Dijkstra/snapping/ETA/turns), search, recommender, reminders, voice arbiter, content validation.
- **Golden screens** in `test_goldens/` (not in CI; regenerate after UI changes and inspect).
- **Python tool tests** in `tools/tests/`.
- **CI** (`.github/workflows/ci.yml`): content validation → PRD.md sync → Python tests → `dart format` → `flutter analyze` → architecture check → `flutter test`; then a release arm64 APK on every PR (workflow artifact) and push. On push to `main` the APK is published as `jelajah-taman.apk` on the **`apk-latest` GitHub Release**, signed with the CI debug key; it is never committed to the repository (ADR 0010).
- **Field testing:** `docs/qa/scenario/` (conventions, result log, traceability), `docs/qa/DEVICE_CHECK.md` (≥2 Android test phones; iPhone can't run the APK).
- **Platforms:** Android only is in scope and committed; `web/` (browser preview) and `ios/` (personal simulator/device runs) stay local (ADR 0011).

## 9. Tech stack (PRD §8.1)

- **On `main` (`pubspec.yaml` is the truth):** Flutter **3.47.9** (pinned in CI; install path per machine) / Dart · flutter_riverpod (no codegen) · go_router · geolocator (+ foreground service) · flutter_map + latlong2 with the bundled vector basemap (PRD still says MBTiles, PROGRESS #26) + optional Esri satellite · own haversine geofence (ADR 0004) and Dijkstra · JSON content + shared_preferences · just_audio · mobile_scanner (bundled ML Kit, offline) · flutter_local_notifications + vibration.
- **Planned / on open feature branches:** audio_service + flutter_tts (F04), pedometer (F08), flutter_compass, permission_handler. The module table in §5.3 lists the intended owner of each.

---

## 10. Where everything lives

| Path | Role |
|---|---|
| `docs/prd/PRD_Kelompok5_Jelajah_Taman.docx` | **Canonical PRD** (v0.9.2). Edit here first. |
| `docs/prd/Kelompok 5_Draft PRD.pdf` | Export of the docx. Re-export after docx edits. |
| `docs/prd/PRD.md` + `docs/prd/figures/` | **Generated** markdown of the PRD (`python tools/prd_to_md.py`). Read this instead of the docx. Never edit by hand; CI fails if stale. |
| `docs/prd/archive/Kickoff_Kel5.pdf` | W7 kickoff report (historical, don't edit). |
| `docs/presentation/` | 15-slide deck `Presentasi_Kel5_Jelajah_Taman.pptx`/`.pdf` (speaker script in slide notes) and the Sprint 1–2 progress deck. |
| `docs/design/DESIGN.md` | UI design system v2. Source of truth for the UI. |
| `docs/design/archive-v1/` | v1 Stitch prompts and hi-fi exports. **Outdated, history only.** |
| `docs/engineering/ARCHITECTURE.md` | Code architecture (§5 above in full). |
| `docs/engineering/IMPLEMENTATION_PLAN.md` | Per-feature build spec: use cases, contracts, data schema, task list T01–T31 with owners and status, decisions D01–D14, as-built notes. PRD wins on conflict. |
| `docs/adr/` | Architecture Decision Records `NNNN-kebab-title.md`, index in `README.md`. |
| `docs/qa/scenario/` | Test scenarios SK-* (Bahasa Indonesia) with AC/TC traceability. |
| `docs/qa/DEVICE_CHECK.md` | Test-phone checklist. |
| `docs/qa/AI_DISCLOSURE_LOG.md` | AI-assisted work log: source of the AI & Tools Disclosure deliverable. |
| `docs/survey/SURVEY_CHECKLIST.md` | Survey trip checklist and post-survey data steps. |
| `docs/content/narration/` | Narration scripts P01–P11 + `manifest.json`. |
| `README.md` | Repo layout, setup, daily commands, definition of done. |
| `lib/core/`, `lib/modules/` | App code (§5). |
| `test/`, `test_goldens/`, `tools/tests/` | Tests. |
| `assets/content/`, `assets/map/`, `assets/images/`, `assets/fonts/`, `assets/audio/` | Bundled content (§6). |
| `tools/` | Validators, generators, checker (§6). |
| `survey/raw/` | Raw survey data (GPX, geo/OSM caches; photos gitignored). |
| `.github/workflows/ci.yml` | CI (§8). |

History: docs moved into `docs/` on 2026-11-06; agent context consolidated into `.agents/`, ADRs split into `docs/adr/`, and QA/survey/archive folders created on 2026-11-22. Removed 2026-11-03 (still in git history, commit 414c626): PRD md mirror, Naskah md, course template docx, `figures/`.

## 11. IDs and markers

| Prefix | Meaning | Defined in |
|---|---|---|
| F01–F08, A01–A07 | Requirements | PRD §3, §3.1 |
| NG01–NG08, G01–G06 | Non-goals, goals | PRD §1.4 |
| PB01–PB21 | Product backlog items | PRD §6 |
| TC-01–TC-13 | Test cases | PRD Lampiran A |
| UI01–UI15 | Screens/states | PRD §5.1 |
| P01–P11, FS01–FS10 | POIs, facilities | PRD §4.1, `assets/content/` |
| D01–D14 | Accepted implementation decisions (in PRD v0.9.1) | IMPLEMENTATION_PLAN §1 |
| T01–T31 | Build tasks | IMPLEMENTATION_PLAN §0.4 |
| R1–R8, E1–E10 | Architecture rules, domain events | ARCHITECTURE §2, §5.2 |
| ADR NNNN | Architecture decisions (older text writes "ADR-008" for ADR 0008) | `docs/adr/` |
| #n | Known issue | `.agents/PROGRESS.md` |
| SK-* | Test scenario | `docs/qa/scenario/` |
| `[VERIFIKASI]` / `[ISI]` | Needs field/manager confirmation / admin data missing — never fill by guessing | — |
