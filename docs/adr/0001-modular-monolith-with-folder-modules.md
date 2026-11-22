# 0001 Modular Monolith with Folder Modules and an Import Checker

Status: Accepted

Date: 2026-11-06

Scope: overall code structure of the Flutter app, module boundaries, dependency direction, enforcement

## Context

Jelajah Taman is a single Android app that runs entirely on the visitor's phone: there is no server (PRD NG05) and every core feature must work offline (A01). It is built by three coders in roughly three weeks, with AI-assisted coding, up to a feature freeze at the end of W13. Most of the risk sits in logic (geofence, routing, recommendation, reminders), and the PRD itself contained logic defects that were found in review. Android plugins (GPS, audio, TTS, notifications) are the most fragile part of the stack.

Boundaries that are only documented tend to erode under deadline pressure, especially when code is generated quickly. Ownership also needs to map onto code so that three people rarely edit the same files.

## Decision

The app is a **modular monolith**: one Flutter project and one build, split into modules under `lib/modules/<m>/`. Each module has exactly one public front door (`<m>.dart`); everything else lives in `src/` (`domain/`, `data/`, `application/`, `ui/`). Modules are arranged in levels 0–5 and may depend only on lower levels, never on the same level and never in a cycle.

Modules are **folders, not separate Dart packages**. The boundaries are enforced mechanically by `tools/check_architecture.dart`, which runs locally and in CI and fails the build on violations.

The full rule set (R1–R8), module catalogue and dependency table are in `docs/engineering/ARCHITECTURE.md` §2–§4.

## Rationale

Folder modules with a checker give the same boundaries as a multi-package workspace at a fraction of the tooling cost (no per-package `pubspec.yaml`, no version wiring, one `flutter test`). Pure domain code (R4) makes the risky logic testable in milliseconds without a phone, GPS or a field trip. Mapping modules to owners keeps merge conflicts rare. Because the folders already follow package boundaries, they can be promoted to a pub workspace later without restructuring.

## Alternatives Considered

- **Dart package per module (pub workspace):** rejected for now; more ceremony than value at 15 screens and three people, and it slows down every dependency change.
- **Layered architecture (one `ui/`, `domain/`, `data/` tree for the whole app):** rejected because it gives no feature ownership and no protection against cross-feature coupling.
- **Clean Architecture with one use-case class per action:** rejected as boilerplate that does not pay off at this size.
- **No enforced boundaries (convention only):** rejected because boundaries would not survive the build period.

## Implementation Details

- Public front door: `lib/modules/<m>/<m>.dart`; private code: `lib/modules/<m>/src/...`.
- Levels: L0 `core`; L1 `content`, `location`, `audio`, `notify`; L2 `routing`, `trigger`; L3 `session`, `map`, `navigation`, `poi`; L4 `search`, `recommendation`, `reminders`, `wellness`; L5 `shell`.
- `tools/check_architecture.dart` checks R1 (front door only), R2 (allowed arrows), R5 (plugins only in the owning module's adapter) and R7 (no `DateTime.now()` outside `core/clock`).
- A new module or dependency arrow requires updating ARCHITECTURE §3/§4 and the checker map in the same change.

## Consequences

Cross-module features are composed in `shell` or coordinated through domain events instead of direct same-level imports. Adding a dependency is a deliberate, reviewed act. Some code temporarily lives in `shell` (all screens and `GuideController`, see ADR 0009) until the owning engines exist; the checker still applies to it.

## Validation

The checker runs in CI on every pull request and push. During setup, a probe file containing deliberate violations was caught by the checker.

## Risks

- The checker covers only R1, R2, R5 and R7; R3, R4, R6 and R8 depend on review.
- A large `shell` module can hide coupling until screens move to their owner modules.

## Follow-up

- Move screens and controller logic out of `shell` into their owner modules as engines land.
- Consider promoting modules to a pub workspace if the codebase outgrows a single package.
