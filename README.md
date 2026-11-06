# Jelajah Taman

Android app (Flutter) that guides visitors through **Tahura Ir. H. Djuanda, zona Dago Pakar** with GPS geofence triggers, audio narration, offline trail navigation, closing-time-aware recommendations and a Wellness Trail mode.
Kelompok 5 · Transformasi Digital · STI ITB 2026 · Topik 7: Public Park & Wellness Explorer.

> **Content is DUMMY data.** Coordinates, distances and durations in `assets/content/` are synthetic until the survey data replaces them. The app shows a banner while any file is dummy. Don't use them for field tests.

## Repository layout

| Path | What |
|---|---|
| `lib/core/` | Shared kernel: Clock, geo maths, EventBus + events E1–E10, logging, Result, theme |
| `lib/modules/<module>/` | Feature modules. Import only `<module>/<module>.dart` from outside. |
| `assets/content/` | `pois.json`, `facilities.json`, `routes.json`, `park.json`, `trail_graph.json` |
| `test/` | Mirrors `lib/` |
| `tools/` | `check_architecture.dart`, `validate_content.py`, `make_dummy_data.py` |
| `docs/prd/` | PRD (docx = canonical, pdf export), kickoff report |
| `docs/presentation/` | Deck (pptx + pdf) |
| `docs/design/` | Design system, Stitch prompts, hi-fi screen exports (`screens/`) |
| `docs/engineering/` | `ARCHITECTURE.md`, `IMPLEMENTATION_PLAN.md`, `DEVICE_CHECK.md`, `SURVEY_CHECKLIST.md` |
| `PROGRESS.md` | Living status, open issues, decisions, log |

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

## Daily commands

```bash
flutter run                               # on a connected Android phone
flutter test
dart run tools/check_architecture.dart    # module boundaries (ARCHITECTURE.md §2)
python tools/validate_content.py          # content data
```

## Definition of done (every PR)

1. CI is green: content validation, format, analyze, architecture check, tests.
2. Domain logic has unit tests (no test, no merge).
3. One other coder reviewed it and can explain the code (A↔B, B↔C, C↔A).
4. Tested on a real Android phone, not only the emulator, for anything touching GPS, audio, notifications or sensors.
5. AI assistance logged for the AI & Tools Disclosure (date, tool, purpose, decision).
6. If behaviour differs from the PRD, the decision is in PROGRESS.md and queued for the PRD Change Log.

Branches: `feat/<module>-<short>` → PR → `main`. Never push directly to `main`.
Commit messages: no `Co-Authored-By` AI trailers or "Generated with" footers; AI use goes in the disclosure log.
