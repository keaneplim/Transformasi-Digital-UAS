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
- `origin/main` = `fc34738` (CI APK commit for `66ecdac`). Since the 20 Nov handoff, `main` gained T23 `TimeBudget` + reminders (`17702cd`), PB10 real QR scanner (PR #10, `ee87c2b`) and an updated Sprint 1–2 progress deck (`66ecdac`).
- Pushed but **not merged** (all by Keane, 21 Nov, stacked on each other): `feat/voice` (F04 voice + media session, D08/T17 weak-GPS card, manual pick, #31 session gate) → `feat/pedometer` (+ F08 step counter, TC-12) → `feat/recommendation` (+ F07 to spec, T24, #34). No PRs open for them yet.
- Branch `docs/agent-context` (this restructure) is open as a PR.
- CI commits `jelajah-taman.apk` after each push to `main`: `git pull` before new work.
- Untracked on purpose: `web/`, `ios/` (local only, ADR 0011).

**Sprint status** — Sprint 4 (16–22 Nov) ends today; feature freeze end of W13. Sprint 5 (23–29 Nov) is field test, usability, fixes.

| Item | Status | What's left |
|---|---|---|
| Sprint 1 PB01–PB05 | code ◐ | No phone test yet (DEVICE_CHECK §3 empty); 5 ESTIMATE coordinates (#28) |
| PB06 geofence + visit log | ☑ code | Evidence video; phone check of restore |
| PB07 notifications | ◐ built | Phone test (lock screen, Dengarkan/Lihat/Nanti, Android 12L+); denied-permission hint |
| PB08 content | ◐ | Final POI texts (all `[ISI]`), photos P03/P09 |
| PB10 QR | ☑ code on `main` | Printed QR P05/P06; TC-04 on 2 phones in airplane mode |
| PB11 eyes-free (F04) | ◐ on `feat/voice` | Review + merge; phone test TC-06 |
| PB12 graph | ⚠ | Built from OSM, not survey GPX: Change Log or validate with `tahura-f.gpx` |
| PB13 search | ☑ code | TC-07 run |
| PB14 navigation | ◐ | Logic in `GuideController`; voice depends on F04; demo arrival 3 m vs 15 m; TC-08 |
| PB15 recommendation (F07) | ◐ on `feat/recommendation` | Review + merge; TC-09/TC-10 |
| PB16 wellness pedometer (F08) | ◐ on `feat/pedometer` | Review + merge; TC-11/TC-12 on a phone |
| PB17 reminders | ◐ on `main` (closing) | System notification + voice for reminders; hydration |

**Next steps, in order**
1. Review and merge `feat/voice` → `feat/pedometer` → `feat/recommendation` (stacked; merge in that order), then pull.
2. First install on ≥2 Android phones now: PB01/02/05/07, offline; fill `docs/qa/DEVICE_CHECK.md` §3.
3. Sourced POI texts (F03) and printed QR codes for P05/P06 before the field test.
4. Sprint 5: run `docs/qa/scenario/` in the field (TC-01…TC-13), usability test (≥5 respondents, SUS), record results.
5. Decide PB12 (OSM vs GPX), #33, #35 (APK commits bloat the repo), branch protection on `main`.

**Last known check results** (20 Nov, `feat/reminders-timebudget`): content 0 errors (33 warnings) · Python tests pass · analyze clean · architecture pass · 167 Flutter tests. Goldens: compare against a render of unchanged `HEAD` on the same machine, not the committed PNGs.

---

## Sessions

### 2026-11-22 — Agent context restructure (branch `docs/agent-context`, Khalfani, Claude Code)
- **Objective:** tidy the agent-facing docs into one folder, following the `.agent/` + `docs/adr/` layout of another project the user maintains, and give the remaining project docs a clear home.
- **Decisions (user):** folder `.agents/` with `AGENTS.md` (complete context), `rules.md`, `MEMORY.md`, `PROGRESS.md`; root `CLAUDE.md` stays as a short loader that references `.agents/`; the PRD stays in `docs/prd/` unchanged; the AI disclosure log is a QA deliverable and moves to `docs/qa/`; ADRs 001–009 are split into `docs/adr/` with three new ones (0010 APK publishing, 0011 Android-only platforms, 0012 design system v2), in English; other docs grouped by function; delivered as a PR.
- **Moves:** `CLAUDE.md` content → `.agents/AGENTS.md` (rewritten, comprehensive) + `.agents/rules.md` (new); `PROGRESS.md` → `.agents/PROGRESS.md`; `LLM_History.md` §1 → `.agents/MEMORY.md`, §2–§4 → `docs/qa/AI_DISCLOSURE_LOG.md`; `docs/scenario/` → `docs/qa/scenario/`; `docs/engineering/DEVICE_CHECK.md` → `docs/qa/`; `docs/engineering/SURVEY_CHECKLIST.md` → `docs/survey/`; `docs/design/STITCH_PROMPTS.md` + `screens/` → `docs/design/archive-v1/`; `docs/prd/Kickoff_Kel5.pdf` → `docs/prd/archive/`. ARCHITECTURE §12 now links to `docs/adr/`.
- **Checks:** `tools/prd_to_md.py` regenerated with no diff (PRD untouched); path references in docs and tools updated; CI checks listed in the PR.
- **Next action:** team members re-read `.agents/AGENTS.md` once; anyone with local edits to moved files rebases after the merge.
