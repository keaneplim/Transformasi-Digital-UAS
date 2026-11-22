# CLAUDE.md — Jelajah Taman (Kelompok 5)

Agent context lives in `.agents/`. This file only loads it and states the few rules that apply to every task.

@.agents/AGENTS.md
@.agents/rules.md
@.agents/MEMORY.md

## Read on demand
- `.agents/PROGRESS.md`: sprint timeline, open questions, known issues (#n), team decisions.
- `docs/prd/PRD.md`: requirements (generated from the canonical docx; never parse the docx).
- `docs/engineering/ARCHITECTURE.md`, `docs/engineering/IMPLEMENTATION_PLAN.md`, `docs/adr/`: how to build it.
- `docs/design/DESIGN.md` for UI work; `docs/qa/` for testing; `CLAUDE.local.md` for this machine's paths and tools.

## Always
- The PRD wins over every other doc. Don't invent facts, coordinates or hours: keep `[VERIFIKASI]` / `[ISI]`.
- Visitor-facing copy in Bahasa Indonesia ("Anda"), no operational detail.
- Follow ARCHITECTURE R1–R8; run the CI checks in `rules.md` §6 before calling a change done.
- Commit, push or open PRs only when asked, on a branch. No `Co-Authored-By` trailers or "Generated with" footers.
- At the end of a substantive session update `.agents/MEMORY.md`, `docs/qa/AI_DISCLOSURE_LOG.md`, `.agents/PROGRESS.md`, and `docs/adr/` when a durable decision was made (`rules.md` §9).
