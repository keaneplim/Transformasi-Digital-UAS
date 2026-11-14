# Jelajah Taman

Android app (Flutter) that guides visitors through **Tahura Ir. H. Djuanda, zona Dago Pakar** with GPS geofence triggers, audio narration, offline trail navigation, closing-time-aware recommendations and a Wellness Trail mode.
Kelompok 5 · Transformasi Digital · STI ITB 2026 · Topik 7: Public Park & Wellness Explorer.

> **Coordinates are real, texts are still draft.** Every POI/facility position has a `coord_source` (`SURVEY_EXIF` from the 7 Nov photos, `OSM`, `GMAPS`, or `ESTIMATE` = needs checking on site) and a `coord_ref`. Place texts, hours and route durations stay `[VERIFIKASI]` until the manager confirms them.

## Repository layout

| Path | What |
|---|---|
| `lib/core/` | Shared kernel: Clock, geo maths, EventBus + events E1–E10, logging, Result, theme tokens, generic UI kit (`core/ui`) |
| `lib/modules/<module>/` | Feature modules. Import only `<module>/<module>.dart` from outside. |
| `lib/modules/shell/src/ui/`, `src/state/` | All screens UI01–UI15 and `GuideController` (real GPS mode, or demo mode from Settings) |
| `assets/content/` | `pois.json`, `facilities.json`, `routes.json`, `park.json`, `trail_graph.json`, `image_credits.json` |
| `assets/map/` | Offline basemap `basemap.json` + `hillshade.png` (generated, OSM ODbL + Google Elevation) |
| `assets/images/`, `assets/fonts/` | Survey photos (metadata stripped) and bundled fonts (offline) |
| `test_goldens/` | Screen baselines, not in CI (`baselines/*.png`) |
| `test/` | Mirrors `lib/` |
| `tools/` | `check_architecture.dart`, `validate_content.py`, `make_dummy_data.py`, `prd_to_md.py`, `gpx_to_graph.py` (survey GPX → `trail_graph.json`), `resolve_coords.py` (photo EXIF / OSM / Places → coordinates), `osm_to_basemap.py` (OSM + elevation → `assets/map/`), `osm_to_graph.py` (OSM paths → `trail_graph.json` + routes), `photos.py` (Commons + survey photos, Gemini retouch, credits), `narration.py` (audio); tests in `tools/tests/` (`python -m unittest discover -s tools/tests`) |
| `docs/prd/` | PRD: docx = canonical, pdf export, `PRD.md` = generated readable copy (`python tools/prd_to_md.py`); kickoff report |
| `docs/presentation/` | Deck (pptx + pdf) |
| `docs/design/` | `DESIGN.md` = design system v2 (source of truth); Stitch prompts and `screens/` = v1, history only |
| `docs/engineering/` | `ARCHITECTURE.md`, `IMPLEMENTATION_PLAN.md`, `DEVICE_CHECK.md`, `SURVEY_CHECKLIST.md` |
| `PROGRESS.md` | Living status, open issues, decisions, log |
| `LLM_History.md` | AI-assisted work log for the AI & Tools Disclosure + session handoff |

## Setup

`android/` is already generated (Flutter **3.47.9**, applicationId `id.ac.itb.kel5.jelajah_taman`). Everyone installs the same Flutter version as CI (`.github/workflows/ci.yml`). After a fresh clone:

```bash
flutter pub get
flutter test
flutter run            # Android phone with USB debugging on
```

How `android/` was generated (for reference only, don't rerun):

```bash
flutter --version                         # Flutter stable; everyone uses the same version
flutter create --platforms=android --org id.ac.itb.kel5 --project-name jelajah_taman .
flutter pub get
dart format lib test tools                # CI fails on unformatted code
flutter analyze
dart run tools/check_architecture.dart
flutter test
git add android pubspec.lock && git commit
```
`flutter create .` only adds missing files; it doesn't overwrite `lib/`, `pubspec.yaml` or `test/widget_test.dart`.

Other platforms are **local only**, never committed (add them to `.git/info/exclude`):

```bash
flutter create --platforms=web .              # browser preview: flutter build web, then serve build/web
flutter create --platforms=ios --org id.ac.itb.kel5 .   # Mac + Xcode only: flutter run -d ios (simulator)
```
Afterwards revert `analysis_options.yaml` and `.metadata` if Flutter touched them.

## Daily commands

```bash
flutter run                               # on a connected Android phone
flutter test
dart run tools/check_architecture.dart    # module boundaries (ARCHITECTURE.md §2)
python tools/validate_content.py          # content data
flutter test test_goldens --update-goldens  # after a UI change: refresh screen baselines (not in CI)
```

The UI currently runs on mock data (demo state, no GPS needed): tap any place → *Navigasi* → *Mulai jalan* to walk the simulated dot. Settings → *Mode demo* teleports, changes walk speed, fakes the clock and fires reminders. Screen baselines for review: `test_goldens/baselines/`.

## Definition of done (every PR)

1. CI is green: content validation, format, analyze, architecture check, tests.
2. Domain logic has unit tests (no test, no merge).
3. One other coder reviewed it and can explain the code (A↔B, B↔C, C↔A).
4. Tested on a real Android phone, not only the emulator, for anything touching GPS, audio, notifications or sensors.
5. AI assistance logged for the AI & Tools Disclosure (date, tool, purpose, decision).
6. If behaviour differs from the PRD, the decision is in PROGRESS.md and queued for the PRD Change Log.

Branches: `feat/<module>-<short>` → PR → `main`. Never push directly to `main`.
Commit messages: no `Co-Authored-By` AI trailers or "Generated with" footers; AI use goes in the disclosure log.
