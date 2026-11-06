# PROGRESS — Jelajah Taman

Living status file. Update at the end of every work session: what changed, what's open, what was decided. Newest first in the Log.

## Timeline
| Milestone | Week | Dates (2026) | Status |
|---|---|---|---|
| Kickoff | W7 | 8 Okt | ✅ Done |
| PRD workshop / baseline v1.0 | W9 | ~20–25 Okt | ⏳ Draft v0.9 presented; PMO decision not recorded |
| Sprint 1 — fondasi & location awareness (PB01–PB05) | W10 | 26 Okt – 1 Nov | ⚠️ Late: skeleton + dummy data added 6 Nov; survey 7 Nov; map/GPS not started |
| **Sprint 2 — POI, trigger logic (PB06–PB10)** | **W11** | **2 – 8 Nov** | **← current** |
| Sprint 3 — core flow + eyes-free (PB11–PB14) | W12 | 9 – 15 Nov | Major Progress Review (end-to-end demo) |
| Sprint 4 — recommendation + Wellness (PB15–PB18) | W13 | 16 – 22 Nov | Feature freeze end of W13 |
| Sprint 5 — field test, usability, fixes (PB19–PB21) | W14 | 23 – 29 Nov | |
| Final deliverables | W15 | | APK, Testing Report, Compliance Matrix, video ≤3 min, AI Disclosure |

## Open questions (need team/lecturer input)
- [ ] Was the PRD baseline approved? Record PMO decision + any revisions in PRD §9 and Change Log §10.
- [x] Where does the app code live? **This repo** (decided 2026-11-06). Survey data goes to `survey/raw/` (small files) + team Drive (photos).
- [ ] Record which ≥2 Android phones are the test devices (team confirmed Android phones are available, 2026-11-06) and fill in docs/engineering/DEVICE_CHECK.md §3.
- [x] `flutter create --platforms=android` done 2026-11-06: analyze clean, 14 tests pass, architecture check passes, debug APK builds. First CI run happens on push.
- [ ] Lecturer answers from kickoff: Tahura Dago Pakar OK for Topik 7? QR fallback OK without permanent install?
- [ ] Lampiran B verification items 1–9 (zone, coordinates, route data, hours/tariff, gua history, permits, GPS quality, Kode MK).

## Known issues in the documents
| # | Issue | Where | Status |
|---|---|---|---|
| 1 | Cover lists only 4 members — Michael Dimas missing | `Kelompok 5_Draft PRD.pdf` | Open |
| 2 | Scenario timing contradicts A03 rule: with 25 min walk the reminder should fire at 15.20, not 14.45; and 10.30 start + 2 j 40 m ends ~13.10, before the 14.45 reminder | PRD §2.1, slide 6, Naskah slide 6 | Open |
| 3 | Cooldown start ambiguous: from trigger time (flowchart) vs. from leaving r+15 m (state diagram) | PRD §3 F02, §4.2 | Open — decide before PB06 |
| 4 | No hysteresis on Approaching (enter and exit both at r+30 m) → repeated vibration at the boundary, contradicts "getar sekali" | PRD §4.2 | Open — e.g. exit at r+40 m or one buzz per approach episode |
| 5 | QR path: figure routes QR → TRIGGER; old md mermaid routed QR → POI Detail | userflow figure (Gambar 2.1) in docx | Open — confirm figure is the intended flow |
| 6 | md mirror lagged docx | `PRD_Kel5_Jelajah_Taman.md` | Closed — file removed 2026-11-03 |
| 7 | Working-tree pptx re-saved by PowerPoint (media renamed/deduped, no text change) — uncommitted | `Presentasi_…pptx` | Safe to commit |
| 8 | Trigger flowchart (Gambar 4.2) evaluates only the single nearest POI → a visited/cooling POI masks an untriggered neighbour inside its radius. Slide 8 says "terdekat yang belum terpicu"; PRD F02 says "terdekat" | PRD Gambar 4.2, F02; slide 8 | Open — fix before PB06 |
| 9 | Approaching (vibrate) is evaluated before the visited/cooldown check → every pass near an already-visited POI buzzes again | Gambar 4.2, Gambar 4.1 | Open — suppress approaching for Visited/Cooldown |
| 10 | Navigation "tiba ≤15 m" → connector B → TRIGGER, but trigger radius is 20–40 m so the POI already triggered on the way in → double trigger; also routes facility (FS, never triggers) arrivals into TRIGGER | Gambar 2.1, F06, UI11 | Open |
| 11 | TRIGGERED marks POI "dikunjungi" even on "Nanti" → walk-bys count as visits (summary 6/10) and are excluded from F07 forever | Gambar 4.2, F07, F08(e) | Open — separate triggered vs visited |
| 12 | P01 "tawaran memulai sesi" impossible: triggers only run during an active session. "Sekali per sesi" exception not modelled in state machine | §4.1 P01, Gambar 4.2 | Open |
| 13 | P11 Curug Omas likely outside NG02 zone (Maribaya end of trail); Trekking "6 km ±4 j incl. Curug Omas" round trip implausible | §4.1, F08, slide 9–10 | Open — verify in survey |
| 14 | TC-10 and slide 10 reuse the wrong 14.45 time from issue #2; TC-10 has no fixed tester position so 15.30 result is not deterministic | Lampiran A, F07 AC3, slide 10 | Open |
| 15 | "GPS lemah > 60 s" rule exists only in Gambar 4.2 + slide 8, not in PRD text | §4.2, F02 | Open |
| 16 | Untested / unspecified: F05 typo tolerance (no AC), F06 slope formula, F07 weights, F08 calorie method (no body weight under NG05), no false-positive AC for F02 | §3 | Open |
| 17 | Deck PDF (22 Okt) older than pptx (27 Okt): title subtitle "Draft v0.9 → Baseline v1.0" removed in pptx only | deck pdf/pptx | Open — re-export |
| 18 | STITCH_PROMPTS references removed `figures/fig_wire_*.png`; Prompt 0 calls caves "WWII-era" (unsourced AI fact; Gua Belanda predates WWII); closing mock uses 15.20 while PRD still says 14.45 | `design/STITCH_PROMPTS.md` | Open |
| 19 | Trail Green #3E8A5B on white = 4.21:1 (< 4.5 for text) despite DESIGN.md "all text ≥4.5:1" | `design/DESIGN.md` | Open — darken to ~#357A4F |

## Decisions
| Date | Decision | By |
|---|---|---|
| 2026-11-03 | Added CLAUDE.md (stable context) + PROGRESS.md (living status) so AI sessions don't re-parse binaries | Keane |
| 2026-11-06 | Architecture: modular monolith (folder modules + import checker), Riverpod without codegen, in-process event bus, Open/Closed only at listed extension points (ARCHITECTURE.md ADR-001…007) | Keane (team to confirm) |
| 2026-11-06 | App code lives in this repo; docs moved to `docs/`; dummy content until survey | Keane |

## Log
- **2026-11-06** — Added task list T01–T30 (4 waves, owners, dependencies, status) as IMPLEMENTATION_PLAN §0.4, plus rule "day 1 together on T01–T02". Moved `notify` module ownership A → C (ARCHITECTURE §3, plan §0.1/§0.2/§2.1, `notify.dart` header) to unload Coder A's critical path. AI-assisted (Claude Code) — log for AI Disclosure.
- **2026-11-06** — Moved docs into `docs/` (prd, presentation, design, engineering). Added Flutter skeleton (`lib/core`, 16 module front doors, content loader, stub TrailRouter, shell Home), DUMMY content (`tools/make_dummy_data.py`), `tools/validate_content.py`, `tools/check_architecture.dart`, CI workflow, tests, README (setup + definition of done), DEVICE_CHECK.md, SURVEY_CHECKLIST.md. Then installed Flutter 3.47.9 and ran `flutter create --platforms=android`: `flutter analyze` clean, 14 tests pass, architecture checker passes (and catches R1/R2/R4/R7 on a probe file), debug APK builds. CI pinned to Flutter 3.47.9. Renamed `Router` → `TrailRouter` (clash with Flutter's Router). AI-assisted (Claude Code) — log for AI Disclosure.
- **2026-11-06** — Created `ARCHITECTURE.md` (modular monolith with folder modules + import checker, Riverpod without codegen, in-process event bus E1–E10, Open/Closed only at listed extension points, ADR-001…007). Updated IMPLEMENTATION_PLAN §2/§4 to match (trigger visited-marking now via `PoiEngaged` event). AI-assisted (Claude Code) — log for AI Disclosure.
- **2026-11-06** — Created `IMPLEMENTATION_PLAN.md`: per-feature spec (use cases, rules, implementation, AC↔TC, done criteria), data files, day-1 contracts, 3-coder split, W12 demo script, risks. Contains proposed decisions D01–D14 resolving issues #2–#4, #8–#12, #15, #16 — need team confirmation, then PRD Change Log. AI-assisted (Claude Code) — log for AI Disclosure.
- **2026-11-05** — Second critical audit (docx, both PDFs, pptx + notes, embedded figures, design/). Confirmed PRD PDF differs from docx only on the cover (#1). Added issues #8–#19 (trigger/flow logic defects, scope, test determinism, design contrast). AI-assisted (Claude Code) — log for AI Disclosure.
- **2026-11-03** — Removed `PRD_Kel5_Jelajah_Taman.md`, `Naskah_Presentasi_Kel5.md`, course template docx, and `figures/` (Keane's request). docx/pdf/pptx are now the only sources.
- **2026-11-03** — Created `design/DESIGN.md` (design system) and `design/STITCH_PROMPTS.md` (master + 14 screen prompts) for hi-fi UI in Google Stitch. Owner of the hi-fi output: Michael Dimas (UX). Closing-reminder mock uses the corrected 15.20 threshold (issue #2).
- **2026-11-03** — Full repo audit (all md/docx/pdf/pptx/figures). Found issues #1–#7 above. Created CLAUDE.md and PROGRESS.md.
