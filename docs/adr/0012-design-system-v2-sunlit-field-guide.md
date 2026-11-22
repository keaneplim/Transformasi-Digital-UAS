# 0012 Design System v2 "Sunlit Field Guide"

Status: Accepted (confirmed by the team 2026-11-22)

Date: 2026-11-12

Scope: visual design, UI kit, copy rules

## Context

Design v1 ("field journal": amber call-to-action, no mascot) existed as Google Stitch prompts and hi-fi screen exports. When the full UI was built in Flutter, v1 had open issues: a text green below the 4.5:1 contrast ratio and prompts that contained an unsourced historical claim. The UI also needed a coherent, implementable token set and components that could be verified with golden tests.

## Decision

The app follows **design system v2, "Sunlit Field Guide"**, documented in `docs/design/DESIGN.md`:

- palette: cream page, sun-yellow header band with drifting doodles and a scalloped canopy edge, forest-green primary actions, terracotta reserved for closing time and destructive actions, sky blue for the visitor's dot;
- type: Bricolage Grotesque for display and numbers (tabular figures), Plus Jakarta Sans for UI and body, both bundled for offline use;
- **Pako**, a pinecone mascot that changes pose with the situation;
- copy rules: Bahasa Indonesia, "Anda", no operational detail in visitor-facing text.

Tokens are implemented as `JT` / `JTText` in `lib/core/theme/app_theme.dart`; shared components in `lib/core/ui/`. v1 material is kept in `docs/design/archive-v1/` for history only.

## Rationale

v2 fixes the v1 contrast problem (text greens at 8.1:1 and 4.9:1), gives the app a recognisable, friendly identity suited to a family park, and is defined directly in code tokens so implementation and design cannot drift.

## Alternatives Considered

- **Keep v1:** rejected for contrast and consistency issues.
- **Plain Material 3 defaults:** rejected; no identity and weak fit with the outdoor, playful context.

## Implementation Details

- Golden baselines of every screen and state at 390×844 and 360×780 in `test_goldens/baselines/` (not in CI; regenerated and inspected after UI changes).
- Tab transitions between Beranda, Peta and Cari are choreographed by `TabStage` (DESIGN.md §6).

## Consequences

All new UI uses the tokens and kit components; hard-coded colours are not allowed. Golden baselines must be regenerated and reviewed after visual changes.

## Validation

Golden tests; contrast values documented in DESIGN.md.

## Risks

Golden images differ across operating systems; comparisons are made against a render of unchanged `HEAD` on the same machine.

## Follow-up

None planned.

## Amendment — 2026-11-22

The team confirmed v2 as the official design of the app, replacing v1 for the product, the presentation and the product video. v1 material remains in `docs/design/archive-v1/` for history only.
