# Agent Rules

Document status: Active
Purpose: operating rules for AI coding agents (Claude Code, Codex, others) working in this repository and keeping `.agents/` up to date.

## 1. Why `.agents/` exists

`.agents/` is the project memory for agent sessions. It exists to:

- keep product, architecture and implementation intent across sessions;
- stop locked decisions from being re-decided;
- keep implementation aligned with the PRD;
- tell the next session exactly where the last one stopped;
- keep AI use traceable for the QA's AI & Tools Disclosure.

## 2. Required read order

At the start of a session:

1. `.agents/AGENTS.md` (project context, file map, spec cheat-sheet)
2. `.agents/rules.md` (this file)
3. `.agents/MEMORY.md` (latest handoff: current state and next steps)
4. `CLAUDE.local.md` if present (machine-specific paths and tools)

Then, only as the task needs:

5. `.agents/PROGRESS.md` (timeline, open questions, known issues, decisions)
6. `docs/prd/PRD.md` (requirements, generated from the docx; never parse the docx)
7. `docs/engineering/ARCHITECTURE.md` and `IMPLEMENTATION_PLAN.md` (how to build it)
8. relevant ADRs in `docs/adr/`
9. `docs/design/DESIGN.md` for any UI work; `docs/qa/scenario/` for test work

## 3. Sources of truth

| Topic | Source | Notes |
|---|---|---|
| Requirements (what) | `docs/prd/PRD_Kelompok5_Jelajah_Taman.docx` | Read via `docs/prd/PRD.md` (generated). |
| Implementation spec (how) | `docs/engineering/IMPLEMENTATION_PLAN.md` | PRD wins on conflict. Requirements are never defined here. |
| Code structure | `docs/engineering/ARCHITECTURE.md` + `docs/adr/` | Rules R1–R8 enforced by `tools/check_architecture.dart`. |
| UI | `docs/design/DESIGN.md` | v1 material in `docs/design/archive-v1/` is history only. |
| Status, issues, team decisions | `.agents/PROGRESS.md` | Issue numbers like "#25" refer to its *Known issues* table. |
| Where the work stands | `.agents/MEMORY.md` | |
| AI use | `docs/qa/AI_DISCLOSURE_LOG.md` | Deliverable for QA. |

If code and docs disagree, do not silently pick one: inspect the repo, name the mismatch, and update the relevant doc in the same change when the change is intentional. When the agent finds that the PRD could be improved, it proposes the change; the PRD is edited only once the team agrees.

## 4. PRD sync rule

A content change to the PRD propagates docx → pdf → `docs/prd/PRD.md` (run `python tools/prd_to_md.py`), and, if it is presented, pptx slide + pptx notes. Commit the docx, pdf and regenerated `PRD.md` together; CI fails when `docs/prd/PRD.md` or `docs/prd/figures/` is stale. List every touched file when reporting.

Reading binaries: `pdftotext -layout file.pdf -`; Python packages `python-docx`, `python-pptx`, `pypdf`, `PIL` (`tools/prd_to_md.py` needs `python-docx`). Not every laptop has all of them; check `CLAUDE.local.md`. On Windows set `PYTHONIOENCODING=utf-8`. Put scratch scripts in the session scratchpad, never in the repo.

## 5. Code rules

- Follow `docs/engineering/ARCHITECTURE.md` §2 (R1–R8). Plugin packages only in their owning module (R5: `flutter_map`/`latlong2` → `map`).
- A new module, dependency arrow or extension point follows ARCHITECTURE §13 and updates the checker in the same change.
- New UI on the Beranda · Peta · Cari pages is wrapped in `Staged` (`TabStage`, DESIGN.md §6).
- Content JSON is DUMMY until survey data replaces it; never invent values to make it look real.

## 6. Verification (local CI parity)

Before reporting a code change as done, run what CI runs:

```text
python tools/validate_content.py
python -m unittest discover -s tools/tests
dart format --output=none --set-exit-if-changed lib test tools test_goldens
flutter analyze
dart run tools/check_architecture.dart
flutter test
```

If the PRD docx changed, also run `python tools/prd_to_md.py` and check `git diff docs/prd/PRD.md docs/prd/figures`.

For UI changes also run `flutter test test_goldens --update-goldens` and open the changed PNGs. Baselines were made on another OS: compare against a render of unchanged `HEAD` on the same machine, not against the committed PNGs.

Report results faithfully, including what was not verified (for example: not tested on a phone).

Gotchas:
- `flutter analyze`/`flutter create`/`flutter build` may rewrite `analysis_options.yaml` (adds `web/**`) and `.metadata`; revert them (`git checkout analysis_options.yaml .metadata`).
- Only `android/` is committed; `web/` (browser preview) and `ios/` (local Xcode runs) stay untracked via `.git/info/exclude` (ADR 0011).
- The APK is published only on the `apk-latest` GitHub Release by CI (ADR 0010, debug-signed). Never commit an APK (`*.apk` is gitignored).
- Stop dev servers, simulators and other long-running processes started during the session once they are no longer needed, unless the user asks to keep them.

## 7. Git

- Team members commit and push themselves. Agents commit, push or open PRs **only when explicitly asked**, on a branch (never directly on `main`).
- **No `Co-Authored-By` trailers and no "Generated with …" footers** in commits or PRs. AI use is disclosed in `docs/qa/AI_DISCLOSURE_LOG.md` instead.
- Commit subjects describe behaviour and may carry the backlog/task id (`PB10: real QR scanner …`, `T23: …`) or a conventional prefix (`docs:`, `fix:`, `ci:`). Avoid subjects that only name a sprint or phase.
- Never commit secrets (`.env.local`, keystores), `tmp/`, or `CLAUDE.local.md`.

## 8. Content and copy rules

- Visitor-facing UI copy: Bahasa Indonesia, "Anda", no operational detail (radius, GPS accuracy, coordinates, DUMMY labels, debug text). See DESIGN.md §8. The collapsed *Mode demo* panel in Settings is the only exception.
- Markers in docs: `[VERIFIKASI]` = needs field/manager confirmation; `[ISI]` = admin data missing. Don't invent values to fill them.
- Historical and location facts must come from the park manager, on-site signboards, or survey data — never from AI alone (PRD §8.2). Flag unsourced facts.
- Don't paste secrets, personal data beyond names/roles already in the PRD, or long chat transcripts into any doc.

## 9. End-of-session updates

After every substantive session, update:

1. `.agents/MEMORY.md` — replace *Current state* and add a session entry at the top (format in that file).
2. `docs/qa/AI_DISCLOSURE_LOG.md` — a session block in §1 (human request, AI output, human decision/correction, verification, result), AI mistakes in §2, a row in §3.
3. `.agents/PROGRESS.md` — timeline/status, new or closed issues, team decisions, a log line.
4. `docs/adr/` — a new ADR or an amendment to an existing one when the session made a durable technical decision (§10).

Also update, when the meaning changed: `.agents/AGENTS.md` (file map, cheat-sheet), `IMPLEMENTATION_PLAN.md` (task status, as-built notes), `ARCHITECTURE.md`, `DESIGN.md`, `README.md`.

Small local edits only need the docs whose meaning actually changed.

## 10. ADR rules

Write an ADR in `docs/adr/` for durable technical decisions: architecture and module boundaries, state management, platform/plugin choices, offline/data strategy, map and content pipelines, CI and release, scope of supported platforms.

- File name `NNNN-kebab-case-title.md`, next free number; add it to `docs/adr/README.md`.
- Sections: Status, Date, Scope, Context, Decision, Rationale, Alternatives considered, Implementation details, Consequences, Validation, Risks, Follow-up.
- Written in English, in a neutral explanatory style for human developers: no references to prompts, chat sessions or sprint bookkeeping.
- If a decision extends or changes an existing ADR, add a dated *Amendment* section to it instead of a duplicate; a reversed decision gets a new ADR and the old one is marked `Superseded by NNNN`.
- Product decisions that change requirements belong in the PRD (Change Log) and `IMPLEMENTATION_PLAN.md` §1 (D-numbers), not in an ADR.

## 11. Adding files to `.agents/`

Keep `.agents/` to the four files listed in `AGENTS.md`. Long-lived topic docs belong under `docs/` (`engineering/`, `qa/`, `design/`, `survey/`), decisions under `docs/adr/`. No scratch files, no duplicated content.
