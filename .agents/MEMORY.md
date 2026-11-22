# MEMORY — Session Handoff

Document status: Active
Purpose: where the work stands, so the next session (human or AI) starts from facts instead of re-reading everything.

How to update (see `rules.md` §9):
- Rewrite **Current state** so it is true at the end of your session (git, sprint status, next steps). Keep it short; details belong in `PROGRESS.md`.
- Add a **session entry** at the top of *Sessions* (newest first): date, branch, who, objective, what changed, decisions, checks run, open items, next action. Keep the last ~5 entries; older ones are summarized in `docs/qa/AI_DISCLOSURE_LOG.md`.
- Facts only. Mark anything not verified as such.

---

## Current state — as of 2026-11-22

**Git**
- `origin/main` = `4df5118` (PR #11 docs/APK release-only, PR #12/#13 F04 voice + F08 pedometer + F07 recommendation + wellness/notify/Settings batch, PR #14 goldens baselines all merged).
- New branch `feat/t25-t23-t31-tracking-finalcall-settings` (Khalfani): implements T25 battery-aware tracking (A06), T23 `FinalCallReminder` (UC-A03-2), and T31 Settings offline version + 7-tap hidden debug menu + Explore debug overlay; PR opened to `main`.
- CI publishes the APK only on the `apk-latest` GitHub Release (no bot commits on `main`, ADR 0010).
- Untracked on purpose on dev Macs: `web/`, `ios/` (local only, ADR 0011).

**Sprint status** — Sprint 4 (16–22 Nov) ends today; feature freeze end of W13. Sprint 5 (23–29 Nov) is field test, usability, fixes.

| Item | Status | What's left |
|---|---|---|
| Sprint 1 PB01–PB05 | code ◐ | No phone test yet (DEVICE_CHECK §3 empty); 5 ESTIMATE coordinates (#28) |
| PB06 geofence + visit log | ☑ code | Evidence video; phone check of restore |
| PB07 notifications | ◐ built; permission rows + Getar ↔ quiet channels 22 Nov | Phone test (lock screen, Dengarkan/Lihat/Nanti, reminder buttons, Getar off, Android 12L+) |
| PB08 content | ◐ | Final POI texts (all `[ISI]`), photos P03/P09 |
| PB10 QR | ☑ code on `main` | Printed QR P05/P06; TC-04 on 2 phones in airplane mode |
| PB11 eyes-free (F04) | ◐ code (incl. TTS reading of POI text when the MP3 fails) | Phone test TC-06 |
| PB12 graph | ⚠ | Built from OSM, not survey GPX: Change Log or validate with `tahura-f.gpx` |
| PB13 search | ☑ code | TC-07 run |
| PB14 navigation | ◐ | Logic in `GuideController`; voice depends on F04; demo arrival 3 m vs 15 m; TC-08 |
| PB15 recommendation (F07) | ◐ code | TC-09/TC-10 |
| PB16 wellness (F08) | ◐ code: steps, distance filter, active time, kcal D11, hydration snooze | TC-11/TC-12 on a phone |
| PB17 reminders | ◐ code: closing + final call (UC-A03-2) + hydration, voice, system notification when hidden | Phone check |
| PB18 Settings | ☑ code: saved on phone, "Izin ponsel", version/offline info, 7-tap hidden debug menu + map overlay | Phone check |
| A06 battery-aware tracking (T25) | ◐ code: `TrackingPolicy` (3 s ↔ 10 s), pedometer wake-up, approaching/nav keep-fast | 60-min battery test on ≥2 Android phones (SK-A06-01/02) |

**Next steps, in order**
1. Merge `feat/t25-t23-t31-tracking-finalcall-settings` after CI passes; prune old merged remote branches.
2. First install on ≥2 Android phones now: PB01/02/05/07, offline; fill `docs/qa/DEVICE_CHECK.md` §3.
3. Sourced POI texts + `key_facts` (F03), P03/P09 photos, 5 ESTIMATE coords (#28), and printed QR codes for P05/P06 before the field test.
4. Sprint 5: run `docs/qa/scenario/` in the field (TC-01…TC-13), usability test (≥5 respondents, SUS), record results.
5. Decide PB12 (OSM vs GPX), #13/#25/#26/#27; branch protection on `main`.

**Last known check results** (22 Nov, `feat/t25-t23-t31-tracking-finalcall-settings`): content 0 errors (33 warnings) · 19 Python tests pass · `dart format` clean · `flutter analyze` clean · architecture check passed · **336 Flutter tests pass**.

---

## Sessions

### 2026-11-22 — T25 battery-aware tracking, T23 final call, T31 version & debug menu (branch `feat/t25-t23-t31-tracking-finalcall-settings`, Khalfani, Ubuntu / Devin)
- **Objective:** complete the remaining code items for T25 (A06 battery-aware GPS interval), T23 (UC-A03-2 final call reminder), and T31 (Settings offline content/app version + 7-tap hidden debug menu & Explore map debug overlay).
- **What changed:**
  - **T25 (A06):** pure Dart `TrackingPolicy` + `TrackingPolicyParams` (`location/src/domain/tracking_policy.dart`, `park.json` params), `LocationService.setInterval`/`currentInterval` + adaptive `noFixAfter` timeout (`LocationServiceImpl`), wired in `GuideController` to GPS fixes, `StepTracker` wake-up, and `keepFast` while approaching any POI or actively navigating.
  - **T23 (UC-A03-2):** `TimeBudget.finalCallAt` + `distanceToGateM`, `FinalCallReminder` (`reminders`, Open/Closed strategy > 200 m from gate at `close − walk`, quiet when already navigating to gate, persisted via `ReminderStore`), `ReminderScheduler.checkOnly` so final call supersedes an open softer card, `GuideReminder.finalCall` with urgent vibration/notification (`TriggerAlerts`), safety voice (`VoiceAlerts`), and urgent terracotta UI13 card (`overlays.dart`).
  - **T31 (UI15):** `ContentRepository.contentVersion`, `GeofenceEngine.debugSnapshot()` + `setWeakBannerForDebug`, *Data offline* & *Versi aplikasi* rows in *Tentang*, 7-tap unlock for `_DebugPanel` (Explore map `_DebugOverlay`, simulated weak-GPS toggle, fine fake-clock stepper/picker, final-call preview, copy session log summary).
- **Decisions (user):** install Flutter 3.47.9 on Ubuntu for local CI parity; 7-tap debug menu unlockable in all builds (including CI release APKs for Sprint 5 QA); final call stays quiet when already navigating to the gate and supersedes an open closing card; T25 keeps 3 s both while approaching POIs and while actively navigating.
- **Checks:** `validate_content.py` 0 errors (33 warnings), 19 Python tests, `dart format`, `flutter analyze`, `check_architecture.dart`, 336 Flutter tests (+24 new tests). Not tested on a physical Android phone yet.
- **Next action:** monitor PR CI (`check` + `build-apk`), merge, then start Android phone checks (`DEVICE_CHECK.md` §3).

### 2026-11-22 — Wellness, reminders, Settings batch (branch `feat/wellness-notify-settings`, Khalfani, Claude Code)
- **Objective:** seven open tasks: key facts on UI06, saved Settings (#32), reminder notifications, hydration snooze (#33), kcal D11 + active time + accuracy filter + re-ask "Aktivitas fisik", PB07 permission hint + Getar ↔ channels, TTS fallback (T07).
- **Decisions (user):** stacked PR on `feat/recommendation` (PR #12, merged), then merge everything to `main`. AI decisions to confirm: hydration text = walked minutes; arriving at a rest point counts as drinking; no lock-screen controls for the read-aloud path; key facts stay empty until sourced.
- **Checks:** format, analyze, architecture, validator, Python tests, 312 Flutter tests; goldens regenerated and looked at, baselines **not committed** (on Khalfani's laptop).
- **Open:** phone check (reminder buttons on the lock screen, quiet channels, permission rows, id-ID voice reading), TC-12.
- **Next action:** pull `main`, install the APK from `apk-latest` on a phone.

### 2026-11-22 — Agent context restructure (branch `docs/agent-context`, Khalfani, Claude Code)
- **Objective:** tidy the agent-facing docs into one folder, following the `.agent/` + `docs/adr/` layout of another project the user maintains, and give the remaining project docs a clear home.
- **Decisions (user):** folder `.agents/` with `AGENTS.md` (complete context), `rules.md`, `MEMORY.md`, `PROGRESS.md`; root `CLAUDE.md` stays as a short loader that references `.agents/`; the PRD stays in `docs/prd/` unchanged; the AI disclosure log is a QA deliverable and moves to `docs/qa/`; ADRs 001–009 are split into `docs/adr/` with three new ones (0010 APK publishing, 0011 Android-only platforms, 0012 design system v2), in English; other docs grouped by function; delivered as a PR.
- **Moves:** `CLAUDE.md` content → `.agents/AGENTS.md` (rewritten, comprehensive) + `.agents/rules.md` (new); `PROGRESS.md` → `.agents/PROGRESS.md`; `LLM_History.md` §1 → `.agents/MEMORY.md`, §2–§4 → `docs/qa/AI_DISCLOSURE_LOG.md`; `docs/scenario/` → `docs/qa/scenario/`; `docs/engineering/DEVICE_CHECK.md` → `docs/qa/`; `docs/engineering/SURVEY_CHECKLIST.md` → `docs/survey/`; `docs/design/STITCH_PROMPTS.md` + `screens/` → `docs/design/archive-v1/`; `docs/prd/Kickoff_Kel5.pdf` → `docs/prd/archive/`. ARCHITECTURE §12 now links to `docs/adr/`.
- **Checks:** `tools/prd_to_md.py` regenerated with no diff (PRD untouched); path references in docs and tools updated; CI checks listed in the PR.
- **Follow-up in the same session:** the team confirmed ADR 0010 and 0012. CI no longer commits the APK (release `apk-latest` only, debug-signed, #35 closed); root APK deleted and `*.apk` gitignored; design v2 is official. ADRs amended, README/DEVICE_CHECK/AGENTS/rules/PROGRESS updated. Per-machine notes moved from root `CLAUDE.local.md` to gitignored `.agents/AGENTS.local.md` (each laptop renames its own copy).
- **Next action:** merge PR #11; team members re-read `.agents/AGENTS.md` once; anyone with local edits to moved files rebases after the merge.
