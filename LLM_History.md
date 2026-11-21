# LLM History — Jelajah Taman (Kelompok 5)

The record of AI-assisted work on this project. It has two jobs:

1. **AI & Tools Disclosure source** (QA: Khalfani). Every AI-assisted change is listed with date, tool, purpose, what the human decided, and how the output was verified, including the mistakes the AI made. PRD §8.2 requires that a team member can explain and has verified anything AI produced.
2. **Session handoff.** §1 says where the work stands, so the next session (human or AI) starts from the facts instead of re-reading everything.

**Rules**
- Append a session to §2 at the end of every AI session (newest first), and update §1.
- Record what the **human decided**, not only what the AI produced. If a human rejected or corrected the AI, write it down; it shows the verification is real.
- AI mistakes go in §3, even when they were caught and fixed.
- Don't paste secrets, personal data beyond names/roles already in the PRD, or long chat transcripts. Summaries only.
- Related files: `CLAUDE.md` (stable context for AI tools), `PROGRESS.md` (project status, issues, decisions). This file doesn't repeat them; it links to them.

---

## 1. Current state (handoff) — as of 2026-11-21, session 8

**Git** (2026-11-20)
- `origin/main` = `origin/keane` = `7fe9455` (fast-forwarded in session 7): PB06, PB07, PB03 GPX, PR #6 tab transitions, PR #7 APK CI, PR #8 test scenarios (`docs/scenario/`), Jacob's 17 Nov progress deck. Every other remote branch is fully in `main`.
- T23 (`17702cd`) and PB10 (`f032b82`) are in `main` via PR #10 (`ee87c2b`).
- Branch `feat/voice` (from `ee87c2b`) = F04 voice part (T07/T15, taken over from C) **plus** (session 8) D08/T17 weak-GPS help card + manual pick + #31 gate, all **uncommitted**, to be committed by Keane (two commits suggested, see session 8) and opened as a PR. Tell Khalfani (voice) and Ballard (T17, `trigger`).
- `feat/voice` committed by Keane as `b4cc3f7` and pushed (PR open). Branch `feat/pedometer` (from `feat/voice`): F08 step counter `ef71342` (committed) + F07 recommendation (session 8 row 6, **uncommitted**).
- CI on push to `main` commits a release APK (`jelajah-taman.apk`, ~46 MB each, issue #35). After it runs, `git pull` before new work.
- Untracked on purpose: `web/` (local preview).

**Team roles for the build** (IMPLEMENTATION_PLAN §0.1)
- Coder A = Ballard, Coder B = **Keane** (+ integrator), Coder C = Khalfani. In session 6 Keane also did A's PB06 and C's PB07 (agreed with the team? — tell Ballard about `trigger`/`session` edits, Khalfani about `notify` + onboarding).

**Sprint status** (details: PROGRESS.md timeline + issues)
| Item | Status | What's left |
|---|---|---|
| Sprint 1 PB01–PB05 | code ◐ | No phone test yet (PB01/02/05, DEVICE_CHECK §3 empty); GPX committed (PB03, `survey/raw/2026-11-07/`); 5 ESTIMATE coordinates (#28) |
| PB06 geofence + visit log | ☑ code | Evidence video; phone check of restore |
| PB07 notifications | ◐ built | **Phone test** (lock screen, Dengarkan/Lihat/Nanti, Android 12L+ no crash) + screenshots; denied-permission hint; "Getar" setting vs channel vibration |
| PB08 content | ◐ | Final POI text (all `[ISI]`), photos P03/P09 |
| PB10 QR | ◐ scanner in `main`; weak-GPS banner + manual pick built 21 Nov (`feat/voice`) | Printed QR P05/P06, TC-04 on 2 phones in airplane mode, SK-F02-15 banner timing in the cave, deep link (optional) |
| PB11 eyes-free | ◐ voice built 20 Nov, media session 21 Nov (`feat/voice`) | Phone check: id-ID voice, lock-screen/earphone controls, interruptions, TC-06 (DEVICE_CHECK §1.6) |
| PB12 graph | ⚠ | Built from OSM, not survey GPX: Change Log or validate with `tahura-f.gpx` |
| PB13 search | ☑ code | TC-07 run |
| PB14 navigation | ◐ | Logic in `GuideController` (not `navigation` module); voice turns + arrival built (`feat/voice`); demo arrival at 3 m instead of 15 m; TC-08 + video |
| B: T23 closing reminder | ◐ in `main` | System notification when hidden (notify, C); voice built in `feat/voice` |

**Next steps, in order** (priority plan of session 7: Musts first, by risk)
1. Commit `feat/voice` (voice + T17 + media session, session 8) and open the PR; install the APK on a phone and run DEVICE_CHECK §1.6 before merging if at all possible (the media session changes `MainActivity`).
2. Team Musts still open: F03 POI texts from sourced facts (content), printed QR P05/P06 (A); agree with C on a reminder notification channel in `notify`.
3. ~~F07 to spec (#34)~~ built in session 8 (uncommitted on `feat/pedometer`); TC-09/TC-10 on GPX replay still to run. Tell Ballard.
4. Keane: decide PB12 (OSM vs GPX). Demo arrival stays at 3 m (session 8: 15 m would stop the simulated walk before the POI triggers).
5. First phone install now, not in field week: PB01/02/05/07, offline; fill DEVICE_CHECK §3.
6. Fix #32, #33 (C); drop the APK commit from CI (#35); branch protection on `main`. (#31 closed in session 8.)

**How to resume an AI session**
- Read `CLAUDE.md`, `PROGRESS.md` and this §1 first. Don't re-parse the PRD docx: read `docs/prd/PRD.md` (generated).
- Flutter 3.47.9 is at `C:\Users\mitba\dev\flutter` (not on PATH). PowerShell: `$env:Path = "C:\Users\mitba\dev\flutter\bin;" + $env:Path`.
- Full local check (same as CI): `python tools/validate_content.py` · `python -m unittest discover -s tools/tests` · `dart format --output=none --set-exit-if-changed lib test tools` · `flutter analyze` · `dart run tools/check_architecture.dart` · `flutter test`.
- Last known result (21 Nov, `feat/pedometer` + F07 uncommitted): content 0 errors (33 warnings) · Python tests pass (19) · analyze clean · architecture pass · 264 Flutter tests; release APK builds. (`flutter test` also rewrites `analysis_options.yaml`: revert it.) Release APK built locally (see session 7 row 6). Goldens: baselines were made on another OS; compare against a render of unchanged HEAD on the same machine, not against the committed PNGs.

---

## 2. Session log (newest first)

### Session 8 — 2026-11-21
**Tool:** Claude Code (VS Code extension), model Claude Opus 5.5. **Human:** Keane.

| # | Human request | AI output | Human decision / correction | Verified by | Result |
|---|---|---|---|---|---|
| 1 | Learn the repo again (new context), "what did we fix for QR" | Summary of PB10. New finding from reading `GeofenceEngine`: the D08 60 s clock only runs on weak fixes, so with no fixes at all (cave) the banner never shows; the banner also had no actions (T17 missing); E7 has no subscriber (F07 AC2 auto sheet) | — | Code reading + full CI set (201 tests) | No code change |
| 2 | List undone features, sorted by priority | Ranked list: Musts with a failing test case first (pedometer, `audio_service`, weak-GPS banner/manual pick, F07 to spec, POI texts, QR boards), then partial/Should, then Could; split per owner | — | grep of `pubspec.yaml`, manifest, content, code | No code change |
| 3 | "ok go, plan and test later" (AI had offered: prepare the voice commit, or fix the weak-GPS banner) | Plan, then built: `GeofenceEngine.tick()` (clock from the last good fix) driven by the controller heartbeat; #31 gate (real-mode fixes reach the engine only in a session); `GuideController.manualPick` + `manualPickList` (UC-A02-3: manual trigger + opened visit, session started if needed, no card/voice prompt); map status chip → help card (*Pindai QR* / *Pilih manual*, denied: *Izinkan lokasi* / *Pilih manual*, "Mencari posisi Anda…"); shared sheet "Anda sedang di mana?"; scanner list button opens it | AI decided **not** to change demo arrival 3 m → 15 m (own earlier suggestion): the simulated walk needs two fixes inside the radius to trigger. First version of the card used the standard buttons; the 360 dp golden showed "Pindai …"/"Pilih manu…" cut off → compact buttons, "Izinkan lokasi". `@visibleForTesting` on `heartbeat()` broke analyze for `test_goldens/` → removed | 10 new tests (211): engine tick, controller banner with no fixes / denied / outside session, manual pick log + order, scanner fallback, map card widget test; goldens 28/29/s360 added and looked at; all other goldens pixel-identical to HEAD (re-render). Compare-mode run shows ~1–2 % glyph-edge diffs on every shot also without visual change (rasteriser) | branch `feat/voice`, uncommitted |
| 4 | "Just do it first" (start `audio_service` before the phone is available) | Plan, then built PR 2 into `feat/voice`: read the plugin's Java/README first (shared engine via `AudioServiceActivity`; the service stops only on idle; Android 12+ foreground-service restart rule → `androidStopForegroundOnPause: false`, switch POI without `stop()`, completed shown as paused). Checked flutter_tts doesn't request audio focus (so our own voice is not an interruption). `MediaSessionNarrationPlayer` replaces the just_audio adapter; buttons and interruptions become `MediaCommand`s handled by the guide; pure `InterruptionPolicy`; Android activity/manifest | Keane chose to build it before the phone check. Decisions by AI, to confirm on a phone: earphone play with a waiting trigger plays that POI; after a call only the interrupted narration resumes; the old adapter was deleted (only change in it was `setVolume`, now in the new one) | 9 new tests (220): policy rules, guide answers to each command, no `stop()` when switching, POI name to the lock screen; full CI set clean; release APK builds (60,5 MB; merged manifest has AudioService (mediaPlayback), MediaButtonReceiver, WAKE_LOCK, FOREGROUND_SERVICE_MEDIA_PLAYBACK). Nothing verified on a lock screen yet | branch `feat/voice`, uncommitted |
| 5 | "Which feature next, one by one" (Khalfani has nothing yet) | Recommended the F08 step counter (only Must with no code, TC-12 fails on a distance estimate). Built it: checked `pedometer` 4.2.0 source first (TYPE_STEP_COUNTER since boot, errors without sensor, declares no permission) and `permission_handler` (13.x → compileSdk 37, so pinned 12.0.3 = Android 13.0.1, compileSdk 35). `wellness`: `StepCounter`, `StepTracker`, `PedometerStepSource`; `shell`: `ActivityRecognitionPermissions`, onboarding asks, "–" without sensor/permission; session record keeps the step snapshot | Keane: "any will do, complete one by one". AI decided: demo mode keeps simulated steps; a reboot mid-session adds the new count instead of dropping it; kcal per D11 left for later | 12 new tests (232): counter rules incl. reboot/restore, tracker states (denied never reads the sensor, no-sensor), guide uses sensor not distance, restore after relaunch; full CI set clean; release APK build (see PROGRESS) | uncommitted |
| 6 | "ok go" (AI had recommended F07 to spec next; step counter committed by Keane as `ef71342` on `feat/pedometer`) | Plan, then built: `recommendation` module (pure `Recommender`, four `ScoreFactor`s, reasons as an enum, copy in shell); guide runs it on E7 from all three sources, once per visited POI, logs it, sets a cue the overlay host turns into UI08; detail close via `PopScope`; Explore button (UC-F07-5); back-to-gate sheet with walk time + *Akhiri Jelajah*; voice line per finish reason; silent `next` notification when hidden | AI found a plan bug: "nearest = 1" / "Terdekat if dist == 1" can't happen with `1 − d/max`; kept the formula, "Terdekat" = shortest walk, plan corrected. AI decisions to confirm with Ballard (owner A): no sheet while navigating (logged only), a new trigger drops a waiting suggestion, closing the detail has no voice line. First golden diff wrongly reported "no pixel change" (Pillow `getbbox` on RGBA only looks at alpha) and restored real changes; caught because the regenerated 18 still showed the old sheet; redone per region | 32 new tests (264): filter/score/tie/reasons/AC4 (pure), AC1 over 200 random visit sets, once per POI, D05, navigation, restart, log + AC2, sheet opens by itself + one tap to navigate (AC5), back-to-gate at 15.30, Explore button, notification + voice. Full CI set clean; goldens 17/18/29/s360 map looked at | uncommitted |

### Session 7 — 2026-11-20
**Tool:** Claude Code (VS Code extension), model Claude Opus 5.5. **Human:** Keane.

| # | Human request | AI output | Human decision / correction | Verified by | Result |
|---|---|---|---|---|---|
| 1 | Learn the repo in detail | Read docs + code, fast-forwarded local `keane` to `origin/keane` (13 commits behind, clean tree). Found: closing reminder + recommendation already in `GuideController` in simplified form; three inconsistent "fits before closing" checks; closing reminder repeats after restore; steps are distance ÷ 0.72 (no pedometer); CI commits a 46 MB APK per push | — | Full CI locally: 146 tests, all green | No code change |
| 2 | Merge what is left into `main` | `main` was an ancestor of `keane` → fast-forward push of `7fe9455` to `main` (no new commit, no PR: `gh` not installed). All other remote branches already in `main` | Keane asked for the merge; later asked "are you sure?" because the newest commit was 3 days old — AI showed `git ls-remote` (main = keane = `7fe9455`) and explained a fast-forward keeps the original commit dates | `git ls-remote` | `main` = `7fe9455` |
| 3 | What is not done yet | Gap list from code, not status columns: F04 (no TTS/media controls), A02 (QR scanner is a mock), F08 pedometer, F03 texts all `[ISI]`, F07 deviations, no phone test | — | grep of `pubspec.yaml`, content, code | No code change |
| 5 | Next feature after T23 | Asked Keane to choose (none of the four missing Musts had code on GitHub). Built PB10 real QR scanner: `mobile_scanner` 7.5.0 checked first (compileSdk 36/minSdk 23 fit Flutter 3.47.9; default bundled ML Kit = offline, unbundled would need a Play Services download), pure payload parser, `QrCamera` in `trigger`, provider bound in the composition root, `GuideController.scanQr`, UI12 with unknown-code message, permission fallback, torch | Keane chose "Real QR scanner" (Coder A's task, Ballard to be told). Decision taken from the plan's UC-A02-1: a scan opens POI Detail directly, no trigger card | 11 new tests (178 total), full CI set clean; screen without camera rendered at HEAD and with the change on the same laptop: identical; release APK builds (60,2 MB, was ~46), CAMERA in the merged manifest. Not on a phone yet | branch `feat/qr-scanner`, uncommitted |
| 6 | "You decide what to handle first, plan first" (phone not available yet) | Chose F04 (the largest Must gap, no TTS on any branch; F06 voice, A03 voice and F08 AC3 wait on it) and split it by risk: PR 1 voice (desk-testable), PR 2 `audio_service` lock-screen/earphone controls (needs the phone). Built PR 1: `VoiceArbiter` (pure, `audio`), `FlutterTtsSpeaker` (flutter_tts 4.2.5, id-ID; compileSdk 36/minSdk 24 checked first; `TTS_SERVICE` query in the manifest for Android 11+), `VoiceAlerts` in shell (prompt, Auto-Play after the prompt ≤ 3 s, navigation start/turns/re-route/arrival, reminders, "Selesai. Berikutnya"), ducking/pausing of the narration, Settings hint when no offline id-ID voice | Keane approved the plan. AI read the plugin's Kotlin source before relying on it: `awaitSpeakCompletion` never completes after `stop()`, so completion uses the plugin callbacks + a timeout. Prompt says "ceritanya" (not every POI is historical); PRD unchanged | 23 new tests (201 total): arbiter rules incl. interruption/resume, stale drop, duck/pause, failing engine, no voice; VoiceAlerts on the real graph (each turn once, ≤ 20 m ahead, in order), Auto-Play timing with fake time. Full CI set clean. Goldens vs a HEAD render on this laptop: only Settings changed (subtitle); 16/23/03 differ only by Pako's blink (16 flips between two HEAD runs too). Release APK (arm64) builds: 60,3 MB, `TTS_SERVICE` query in the merged manifest. Not on a phone yet | branch `feat/voice`, uncommitted |
| 4 | Recommend what to build first; plan first, correctness over speed | Plan: Must gaps first by risk; Keane's T23 first because it is small, pure, and blocks A's F07 and C's hydration. Then built T23: `TimeBudget` (routing), `reminders` module (`ReminderScheduler`, `ClosingReminder`, `HydrationReminder` moved unchanged, `ReminderStore`), wiring in `GuideController`, one route-fit rule for Home + route chooser | Keane approved the plan. AI left the system notification for reminders out because it changes C's `notify` module (needs C's agreement) | 21 new tests (167 total) incl. TC-10 at P06 on the real graph; restart test checked by mutation (fails without the fix); format, analyze, architecture, validator clean. Goldens not regenerated: same results at the goldens' times | branch `feat/reminders-timebudget`, uncommitted |

### Session 6 — 2026-11-14
**Tool:** Claude Code (VS Code extension), model Claude Opus 5.5. **Human:** Keane.

| # | Human request | AI output | Human decision / correction | Verified by | Result |
|---|---|---|---|---|---|
| 1 | Explain the repo in detail | Walkthrough of architecture, modules, router, demo state; ran full CI on `main` | — | CI checks locally | No code change |
| 2 | Pull the new pushes to `main`, then switch to `keane` and update it | Resolved the stash-pop conflict in PROGRESS.md (took upstream, re-inserted Keane's 10 Nov log line; backup kept in the session scratchpad), reverted Flutter's `.metadata`/`analysis_options.yaml` rewrites, fast-forwarded `main` and `keane` to `1a3d59c`; local edits re-applied | Keane asked for both pulls | `git status`; full CI after pull: 103 tests | `keane` = `1a3d59c` + uncommitted edits |
| 3 | Status of Coder B tasks and Sprints 1–3 | Per-PBI done / not-done tables from code (not only docs): no phone test yet (PB01/02/05), GPX not committed (PB03), notifications/QR scanner missing (PB07/PB10), PB11 not started, graph from OSM instead of survey GPX (PB12) | — | Read code, manifest, content, DEVICE_CHECK | No code change |
| 4 | PB06: finish geofence + visit log (evidence video later) | Bug fix: the engine was not reset on `startSession()`, so POIs visited in an earlier session never triggered again until "reset all". D06 fix: arrival (`markVisited`) no longer emits a `PoiTriggered`; new `GeofenceEngine.visitOnArrival` (Visited, source nav). Visit log + session restore: `session` module gets `SessionRecord`/`VisitEvent` (domain) and `SessionStore` (keys `session.current`/`session.last` in the existing `KeyValueStore`, no SQLite); `GeofenceEngine.toJson/restore`; `GuideController` logs every trigger/visit with source, saves at once on events and every 15 s while walking, restores an unfinished same-day same-mode session after the app is killed (re-starts background tracking after GPS start to avoid a race), archives stale ones; publishes E1/E2. AI caught two of its own bugs before running: `finish()` cleared "current" after writing "last" (could wipe a session started right after), and a test walk too fast for the 3.5 m/s glitch filter | Keane chose PB06 first and to postpone the video | 14 new tests (engine 4, session record/store 4, controller 6; one verified by mutation — removing the fix makes it fail); format, analyze, architecture pass; 117 Flutter tests pass. Goldens: regenerated, all 50 differ, but a control run of unchanged HEAD on the same laptop differs identically (Windows text rendering vs the baselines' machine); against that control only Pako blink frames differ → the change alters no screen. Regenerated PNGs discarded, not committed | uncommitted on `keane` |
| 5 | PB07: plan first, be critical; PRD may be improved if needed | Analysis from the plugin source, not memory: non-UI notification buttons always run in a separate Flutter engine (→ T12 option b, forward via `IsolateNameServer`); the plugin doesn't register its `ActionBroadcastReceiver` (buttons would silently do nothing); 23.x needs compileSdk 37 → pinned 22.0.0; desugaring + androidx.window needed; background vibration unreliable → approach via a notification channel; `cancelAll()` would hit the GPS service notification → cancel own ids only. Built `notify` module, `TriggerAlerts` (shell), app lifecycle + cold-start tap, onboarding permission, Android config, status-bar icon. Found + logged #31 (in-app trigger card outside a session) and #32 (onboarding every launch) | Keane approved the plan (v22, approach notification in both states) and set the rule that the PRD may be changed when a better design exists (saved as AI memory). No PRD change was needed | 18 new tests (135 total); analyze, format, architecture, content, Python tests pass; debug APK builds; merged manifest contains the receiver + permissions, APK contains the icon. **Not verified on a phone** (lock screen, buttons, 12L+) | uncommitted on `keane` |

### Session 5 — 2026-11-12
**Tool:** Claude Code (VS Code extension), model Claude Opus 5.5. **Human:** Keane.

| # | Human request | AI output | Human decision / correction | Verified by | Result |
|---|---|---|---|---|---|
| 1 | Look at the repo in detail, learn it, read the md | Read-only review of all docs and code; fetched remotes and found new work on `ballard` and `ui-revamp`; ran full CI on `main` and on both branches in throwaway worktrees. Findings: `ballard` doesn't compile (duplicate `LocationFix`/`GpsQuality`/`TriggerSource`/`PoiState` in a new `lib/core/models/`, `geolocator` missing from pubspec, `PoiApproached` without `at`, nonexistent `markVisited`/`Clock.now()`/`MockContentRepository`/`GeoPoint.offsetFrom`; logic: no Triggered/Visited → Cooldown transition so a POI never re-triggers, QR/manual publish no events, manual pick marks Visited instead of Triggered). `ui-revamp` passes CI but puts all screens and a demo engine in `shell`, rewrites DESIGN.md, deletes the T04 Explore screen. Updated §1 here | Pending: Keane to pass the findings to Ballard and Khalfani | `main`: content 0 errors, 13 Python + 44 Flutter tests, analyze, format, architecture pass. `ballard`: 60 analyzer issues, tests fail to load. `ui-revamp`: analyze clean, architecture pass, 44 tests pass | No code change |
| 2 | Check GitHub: what's updated, has every branch pushed, how is main | Fetched: `ui-revamp` merged as PR #1 (`f02d168`, self-merged, no reviewer), CI green; `ballard` pushed but not mergeable; `khal` unused; local `main` 4 behind with overlapping uncommitted edits. Updated §1 | — | GitHub Actions + PR API, `git rev-list` | No code change |
| 3 | When is Coder B's last feature; POI + GPX already recorded, not exported | B schedule from plan §0.4 (feature freeze 22 Nov); export order: POI coordinates into `pois.json` before `gpx_to_graph.py` (the tool doesn't read POI pins) | — | Read `tools/gpx_to_graph.py` | No code change |
| 4 | Add a 12 Nov progress slide to the Sprint 1–2 progress deck | Slide 4 in `docs/presentation/Progres_Sprint1-2_Kel5_Jelajah_Taman.pptx` (same layout as slide 3): progress 10–12 Nov + rest of Sprint 3, with speaker notes | Keane supplied that GPX and POI points are recorded but not exported; team to review before presenting | Validator passed; rendered in PowerPoint and checked | uncommitted |
| 5 | Check for new Khalfani branches | Found `audio-narration` and the direct push `35cf8db` to `main`; listed PRD conflicts of the narration (length, AI TTS vs recorded, Wikipedia sources) | — | `git fetch`, read scripts + `pois.json` sources | No code change |
| 6 | Merge `audio-narration` into `main`, check first | Full CI in a throwaway worktree: content 0 errors, PRD in sync, 13 Python tests, format, analyze, architecture, 48 Flutter tests all pass; 11 MP3s present, sizes match `audio_seconds`. Goldens fail 39/41, identically on `main` (baselines made on another OS; not in CI). Fast-forwarded `main` to `600d176` and pushed (no merge commit) | Keane asked for the merge after seeing the PRD conflicts; those stay open as follow-ups (PRD F03 change or shorter clips; source check per §8.2) | Local CI run; GitHub Actions on `600d176` | `main` = `600d176` |

### Session 4 — 2026-11-10
**Tool:** Claude Code (VS Code extension), model Claude Opus 5.5. **Human:** Keane.

| # | Human request | AI output | Human decision / correction | Verified by | Result |
|---|---|---|---|---|---|
| 1 | Look at the repo in detail | Read-only review: status, code, spec, all local CI checks; flagged turn-instruction gaps (shallow forks, start at a junction) and the `TriggerEngine` contract mismatch | Not fixed yet | Local checks: content 0 errors, 13 Python and 44 Flutter tests, analyze, format, architecture all pass | No code change |
| 2 | Progress report PPT for Sprint 1–2, with members and NIM | `docs/presentation/Progres_Sprint1-2_Kel5_Jelajah_Taman.pptx`; status updates in PROGRESS.md and §1 here | Keane supplied the survey facts and the Coder A/C assignment; team to review the deck before presenting | Validated the file, rendered all slides in PowerPoint and checked them | uncommitted |

### Session 3 — 2026-11-06 (long session; context was compacted once and continued)
**Tool:** Claude Code (VS Code extension), model Claude Opus 5.5. **Human:** Keane (BA, then Coder B). **Mode:** user asked for a blunt, critical expert stance rather than agreement.

| # | Human request | AI output | Human decision / correction | Verified by | Result |
|---|---|---|---|---|---|
| 1 | Detailed per-feature implementation spec with use cases | `docs/engineering/IMPLEMENTATION_PLAN.md`: use cases, rules, AC↔TC, data schema, contracts, risks, proposed decisions D01–D14 | Accepted; D01–D14 confirmed later (item 7) | Keane reviewed | `d2cefc2` |
| 2 | Modular-monolith architecture, Open/Closed, discuss first | `docs/engineering/ARCHITECTURE.md`: modules/levels, rules R1–R8, events E1–E10, extension points, ADR-001…007 | Accepted the recommendation | Keane reviewed; rules enforced by `tools/check_architecture.dart` (a probe file with violations was caught) | `d2cefc2` |
| 3 | Pushable skeleton + CI, dummy coordinates until the survey, docs into `docs/` | Flutter skeleton (`lib/core`, 16 module front doors, content loader, stub router), dummy content generator, content validator, architecture checker, CI workflow, README, DEVICE_CHECK, SURVEY_CHECKLIST | Keane: the team has Android phones, so the iPhone 14 is not a blocker | `flutter analyze` clean, 14 tests, debug APK built | `d2cefc2` |
| 4 | Install Flutter if needed | Installed Flutter 3.47.9 locally; ran `flutter create --platforms=android` | — | Build + tests ran | `d2cefc2` |
| 5 | Feature/task list for 3 coders with pairings and order | Task list T01–T30 in 4 waves, critical paths, pairing reasons; added to plan §0.4 | Keane: don't write Ballard as Coder A yet → names set to _TBD_ | Keane reviewed | `d2cefc2` / `ec24a1b` |
| 6 | Git commands (commit, push, 3 branches) | Commands only | Keane ran them (no AI commits) | `git log` output checked | branches `keane`, `ballard`, `khal` |
| 7 | Apply accepted decisions D01–D14 to PRD/spec | PRD docx → v0.9.1 (F01, F02, F05–F08, §2.1, §4.1, §4.2, UI11, TC-02, TC-10, Change Log), PDFs re-exported, deck slides 6/7/8/10 + notes | Keane accepted all 14 | Text checked in the exported PDF; old times 14.45/10.30 gone; slides rendered, no overflow | `ec24a1b` |
| 8 | Separate PRD from the implementation plan | `tools/prd_to_md.py` → generated `docs/prd/PRD.md` + figures; CI fails if it's stale | Accepted | CI step; LF line endings fixed | `ec24a1b` |
| 9 | "Why can't I find my repo on GitHub?" | Checked: repo exists, public, all branches pushed; likely wrong account/search lag | AI flagged that the repo is public and contains names/NIMs: team to decide on visibility | HTTP + API check | — |
| 10 | Is the workload equal for A, B, C? Is all UI with C? | Analysis: A overloaded, B idle in wave 3, A held integration; UI is per feature (vertical slices) | Keane approved two rebalances: T03 → C, T23 + `TimeBudget` → B, T29 split (UI14 → B, new T31 Settings → C), integrator → B, T20 Search → A, T08 starts in wave 0 | Per-wave load table in plan §0.4 | `883bf85` |
| 11 | "I'm Coder B, what's wave 0?" → implement T04 | `map` module (geometry, scene, `ExploreMap` widget), Explore preview screen with debug long-press position, temporary map button on Home | Accepted; Keane = Coder B recorded in the plan | 16 new tests; a widget test exposed real marker overlap → issue #21 | `4161687` |
| 12 | Write T13 GPX → graph before the survey | `tools/gpx_to_graph.py` (stdlib only) + 13 tests on synthetic survey walks; SURVEY_CHECKLIST §8 command; CI step for Python tool tests | Accepted | Tests across 10 noise seeds; end-to-end: validator 0 errors, Dart loads the graph. Own tests caught 3 bugs before shipping (see §3) | `2642cf6` |
| 13 | "Have you tested all? Is wave 0 done?" | Ran all CI checks; listed what is NOT tested (phone, real GPX); A/C unassigned = main risk | AI corrected its own earlier advice (see §3) | Full local CI run | — |
| 14 | Plan, then implement T14 router | Plan file approved by Keane, then `GraphTrailRouter` (snapping, Dijkstra on time, D09 ETA, turn instructions); stub removed; `TurnInstruction.distanceFromStartM` added | Plan approved before coding | 17 routing tests; on a noisy GPX-generated graph the turn instructions were identical to the clean graph for all 11 POIs | `0e62e5c` |
| 15 | Create this file | `LLM_History.md`; pointer added to CLAUDE.md | — | — | uncommitted |

### Session 2 — 2026-11-05
**Tool:** Claude Code (per PROGRESS log). **Human:** Keane.
- Second critical audit of the docx, both PDFs, pptx + notes, embedded figures and `design/`. Confirmed the PRD PDF differed from the docx only on the cover (#1). Added issues #8–#19: trigger/flow logic defects, scope, test determinism, design contrast.
- **Human decision:** fixes were proposed, not applied; most were later resolved through D01–D14 (session 3, item 7).

### Session 1 — 2026-11-03
**Tool:** AI-assisted; tool and model not recorded at the time (likely Claude Code; **QA to confirm**). **Human:** Keane.
- Full repo audit (md/docx/pdf/pptx/figures) → issues #1–#7; created `CLAUDE.md` and `PROGRESS.md`.
- Removed the PRD md mirror, Naskah md, course template docx and `figures/` at Keane's request (still in git history, `414c626`).
- Created `design/DESIGN.md` and `design/STITCH_PROMPTS.md` for hi-fi UI in Google Stitch (owner of the hi-fi output: Michael Dimas, UX).

### Before session 1
The PRD, deck and speaker script (commit `414c626`) predate this log. **QA to fill in** whether and how AI was used for them.

---

## 3. AI mistakes and corrections

Listed for honest disclosure. All are fixed unless marked open.

| Date | What went wrong | Caught by | Fix |
|---|---|---|---|
| 2026-11-06 | AI wrote a literal `\n` instead of a line continuation in the CI "PRD.md in sync" step; it only worked by accident (bash read it as an extra path `n`) | AI, later in the same session | Fixed in `2642cf6` |
| 2026-11-06 | AI's draft plan named Ballard as Coder A before the team decided | Keane | Names set to _TBD_ |
| 2026-11-06 | AI treated the iPhone 14 as a possible test device problem; the team has Android phones | Keane | DEVICE_CHECK keeps the iPhone for survey use only |
| 2026-11-06 | First rebalance only fixed wave 3; waves 1–2 were still uneven | AI, when Keane asked "all balanced?" | Second rebalance (session 3, item 10) |
| 2026-11-06 | AI advised "don't start the router (T14) until the real graph exists"; too strict, the plan itself says the dummy graph is fine | AI, next answer | Corrected; T14 built on the dummy graph |
| 2026-11-06 | `gpx_to_graph.py` v1: speed filter dropped normal GPS jitter (3,086 points) | AI's own tests | Jump must be > 10 m **and** > 3 m/s |
| 2026-11-06 | `gpx_to_graph.py` v1: GPS jitter inflated trail lengths (and every ETA) by ~17% | AI's own tests | Smooth before and after resampling (±0.6%) |
| 2026-11-06 | `gpx_to_graph.py`: a junction was missed when the walker turned back exactly at a trail; one test seed passed by luck and hid it | AI, multi-seed robustness check | Joining logic rewritten; test now runs 5 seeds |
| 2026-11-05 | (found in audit, origin unknown) STITCH_PROMPTS calls the caves "WWII-era", an unsourced fact (Gua Belanda predates WWII) | AI audit | **Open**: issue #18 |
| 2026-11-20 | First draft of `ClosingReminder` put the gate's graph node id into `ReminderDue.actionDestinationId`, which is documented as a POI id | AI, re-reading the event contract | Passes `gatePoiId` (P01) |
| 2026-11-20 | Scan-screen widget test first used a semantics-label finder (semantics is off in tests) and the phone-size view, where the wide test font overflows the code list by 35 px | AI's own test run; golden with real fonts showed no overflow | Tap the visible name; taller test view, layout covered by golden 21 |
| 2026-11-20 | Two new controller tests failed at first: jumping the fake clock from 10.00 to 15.xx also made the 45 min hydration reminder due, which correctly took the slot | AI's own test run | Hydration off in those tests; the scheduler's priority is tested separately |
| 2026-11-20 | First `VoiceArbiter`: a line taken off the queue was not yet "current" while the voice-support check was awaited, so the same text could be queued and said twice (and an interruption in that moment was missed) | AI's own test (duplicate text) | The line becomes current before the await; interrupted/cancelled lines are re-checked after it |
| 2026-11-20 | First `VoiceAlerts` said "Anda tiba di Gua Belanda." from navigation right before the trigger prompt "Anda tiba di Gua Belanda. Ingin mendengar ceritanya?" | AI, reading the event log of its own test | Arrival line skipped when that POI's prompt is showing; tested both ways |
| 2026-11-06 | Minor tooling slips: Python escaping in shell heredocs, a `sed` edit that silently didn't apply, CRLF line endings from the PRD generator on Windows | AI | Switched to the edit tools; `newline="\n"` + `.gitattributes` |

---

## 4. Disclosure summary (for the AI & Tools Disclosure section)

| Date | Tool | Purpose | Human decision / verification |
|---|---|---|---|
| 2026-11-03 | AI assistant (tool to confirm) | Repo audit; CLAUDE.md/PROGRESS.md; design system + Stitch prompts | Keane reviewed; hi-fi screens produced by the UX designer |
| 2026-11-05 | Claude Code | Second audit of PRD/deck/design | Findings logged as issues; fixes decided by the team |
| 2026-11-06 | Claude Code (Claude Opus 5.5) | Implementation plan, architecture, decisions D01–D14 applied to PRD v0.9.1 and deck | Team accepted D01–D14; PDF/slides checked after export |
| 2026-11-06 | Claude Code (Claude Opus 5.5) | Flutter skeleton, CI, content validator, architecture checker | Builds, analyzer and tests run locally; checker proven on a violation probe |
| 2026-11-06 | Claude Code (Claude Opus 5.5) | Coder workload split and rebalancing | Keane approved each change |
| 2026-11-06 | Claude Code (Claude Opus 5.5) | Code: Explore map (T04), GPX → graph tool (T13), router (T14) | Unit/widget tests (44 Flutter + 13 Python), end-to-end checks; Coder B (Keane) must be able to explain the code; phone test of T04 and real-GPX run of T13 still pending |
| 2026-11-10 | Claude Code (Claude Opus 5.5) | Repo review; Sprint 1–2 progress report deck | Status facts supplied by Keane or checked against the repo; slides rendered and checked; team to review before presenting |

No facts about Tahura (history, coordinates, hours, routes) were taken from AI. All such values in the app are DUMMY or marked `[VERIFIKASI]` until the survey and the park manager confirm them (PRD §8.2).
