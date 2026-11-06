# CLAUDE.md — Jelajah Taman (Kelompok 5)

Context for AI assistants. Read this instead of re-parsing the binaries. Current status lives in @PROGRESS.md.

## Project
Tugas Besar **Transformasi Digital** (Prof. Ir. Kridanto Surendro, STI ITB, 2026), **Topik 7: Public Park & Wellness Explorer**.
**Jelajah Taman** = Android app (Flutter) that guides visitors through **Tahura Ir. H. Djuanda, zona Dago Pakar** (gerbang Dago Pakar → Gua Belanda–Gua Jepang) with GPS geofence triggers, audio narration, offline trail navigation, closing-time-aware recommendations, and a Wellness Trail mode.
Deliverable language: **Bahasa Indonesia**, formal-academic.

| Member | NIM | Role | Presents slides |
|---|---|---|---|
| Jacob Reinhard Marudut Siagian | 18223026 | PM / Scrum Master | 1, 2, 12, 15 |
| Keane Putra Lim | 18223056 | Business Analyst | 3, 4, 5 |
| Michael Dimas Sarono | 18223076 | UX/UI Designer | 6, 11 |
| Michael Ballard Silaen | 18223080 | Developer | 8, 9, 10, 13 |
| M Khalfani Shaquille Indrajaya | 18223104 | QA (+ AI disclosure log) | 7, 14 |

## Files & source of truth
| File | Role |
|---|---|
| `docs/prd/PRD_Kelompok5_Jelajah_Taman.docx` | **Canonical PRD** (v0.9). Edit here first. |
| `docs/prd/Kelompok 5_Draft PRD.pdf` | Export of the docx (29 pp). Re-export after docx edits. Greppable via `pdftotext`. |
| `docs/prd/Kickoff_Kel5.pdf` | W7 kickoff report (historical, don't edit). |
| `docs/presentation/Presentasi_Kel5_Jelajah_Taman.pptx` / `.pdf` | 15-slide deck; speaker script lives in each slide's notes. |
| `docs/design/DESIGN.md`, `docs/design/STITCH_PROMPTS.md` | UI design system (palette, type, components) + Google Stitch prompts per screen UI01–UI15. |
| `docs/engineering/ARCHITECTURE.md` | Code architecture: modular monolith, modules/levels, dependency rules R1–R8, event catalogue E1–E10, Open/Closed extension points, ADRs. |
| `docs/engineering/IMPLEMENTATION_PLAN.md` | Per-feature build spec for the coders (use cases, contracts, data schema, owners, decisions D01–D14). PRD wins on conflict. |
| `docs/engineering/DEVICE_CHECK.md`, `SURVEY_CHECKLIST.md` | Test-phone checklist (incl. iPhone 14 = can't run the APK) and survey trip checklist. |
| `README.md` | Repo layout, first-time setup, daily commands, definition of done. |
| `lib/`, `test/`, `assets/content/`, `tools/` | Flutter app (modular monolith, see ARCHITECTURE.md), tests, JSON content (**DUMMY until survey**), checker/validator scripts. |
| `.github/workflows/ci.yml` | CI: content validation, format, analyze, architecture check, tests; debug APK on push to main. |

Docs moved into `docs/` on 2026-11-06. Removed 2026-11-03 (still in git history, commit 414c626): PRD md mirror, Naskah md, course template docx, `figures/` (the figures are embedded in the docx/pptx).

**Sync rule:** a content change to the PRD must propagate docx → pdf, and, if it is presented, pptx slide + pptx notes. List every touched file when reporting.

**Reading binaries** (tools available on this machine): `pdftotext -layout file.pdf -`; Python 3.13 has `python-pptx`, `python-docx`, `pypdf`, `PIL`. Set `PYTHONIOENCODING=utf-8` (Windows console is cp1252). Put scratch scripts in the session scratchpad, not the repo.

## Spec cheat-sheet (PRD v0.9)
- **Core reqs (all Must):** F01 Location Awareness · F02 Location-Based Trigger · F03 Multimodal (foto, teks 80–150 kata, audio 60–120 s) · F04 Eyes-Free · F05 Search · F06 Navigation (GPX trail graph + Dijkstra, ETA 3 km/h + slope) · F07 Contextual Recommendation · F08 Wellness Trail Explorer (domain innovation).
- **Additional:** A01 Offline (Must) · A02 QR fallback (Must) · A03 Closing reminder · A04 Facility finder · A05 JSON content (Should) · A06 Battery · A07 Accessibility (Could).
- **Non-goals NG01–NG08:** no ticketing, only Dago Pakar, no AR/BLE/CV, no CMS, no accounts/server data, no SOS/tracking, no transactions, Indonesian only.
- **Trigger params:** GPS every ±3 s / ≥3 m; accuracy >30 m = "GPS lemah", ignored. Approaching ≤ r+30 m (vibrate + sound). Triggered = 2 consecutive readings ≤ r. Re-trigger needs exit > r+15 m **and** 10 min cooldown. States: Outside → Approaching → Triggered → Visited → Cooldown; QR jumps straight to Triggered. Layers: GPS → QR (`jelajahtaman://poi/P05`) → manual pick.
- **Recommendation filter:** walk to POI + visit time + walk POI→gate ≤ time to close − 15 min; score by walking distance (highest weight), interest, active route, difficulty; 1 main + 2 alternatives; else "Kembali ke gerbang".
- **Closing reminder (A03):** fires at jam tutup − walk-to-gate − 15 min. Hours ±08.00–16.00 [VERIFIKASI].
- **POIs (radius):** P01 Gerbang 30 · P02 Monumen 25 · P03 Museum 25 · P04 Kolam Pakar 30 · P05 Gua Jepang 20+QR · P06 Gua Belanda 20+QR · P07 Penangkaran Rusa 30 · P08 Hutan Pinus 40 · P09 Area Piknik 40 · P10 Koleksi Flora 25 · P11 Curug Omas 40 (optional, Trekking only). Facilities FS01–FS05 (toilet, musala, warung, pos petugas, istirahat) never trigger.
- **Routes [VERIFIKASI]:** Santai 2,5 km ±2 j · Sedang 4 km ±3 j · Trekking 6 km ±4 j.
- **Tests:** TC-01…TC-13 (Lampiran A). Usability ≥5 respondents, SUS ≥68. Pedometer error ≤10% on 200 steps.
- **Stack:** Flutter/Dart; geolocator + foreground service; flutter_map + offline OSM MBTiles; own haversine geofence + Dijkstra; pois.json + SQLite/SharedPrefs; just_audio + audio_service + flutter_tts; mobile_scanner; flutter_local_notifications + vibration; pedometer.
- **Backlog:** PB01–PB21 across Sprints S1–S5 (see PROGRESS.md for dates).
- **Code rules:** follow docs/engineering/ARCHITECTURE.md §2 (R1–R8); run `dart run tools/check_architecture.dart` and `python tools/validate_content.py`. Flutter 3.47.9 is installed at `C:\Users\mitba\dev\flutter` but not on PATH (PowerShell: `$env:Path = "C:\Users\mitba\dev\flutter\bin;" + $env:Path`). Verify changes with `flutter analyze`, `flutter test`, `dart run tools/check_architecture.dart`.

## Conventions
- Markers in docs: `[VERIFIKASI]` = needs field/manager confirmation; `[ISI]` = admin data missing. Don't invent values to fill them.
- Historical/location facts must come from the manager, on-site signboards, or survey data — never from AI alone (PRD §8.2). Flag unsourced facts.
- Any AI-assisted work should be loggable for QA's AI & Tools Disclosure (date, tool, purpose, decision).
- Git: team members commit and push themselves. AI tools must NOT add `Co-Authored-By` trailers or "Generated with …" footers to commits/PRs (AI use is disclosed in the AI & Tools Disclosure log instead). Don't commit unless explicitly asked.
