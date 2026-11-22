# 0002 Riverpod without Code Generation; Hand-Written Models

Status: Accepted

Date: 2026-11-06

Scope: dependency injection, state management, data models

## Context

The app needs one way to wire implementations (real GPS vs replay, real clock vs fake clock, production vs test adapters), to hold UI state, and to override dependencies in tests. The data model is small: about ten content models read from JSON (POIs, facilities, routes, park config, trail graph) plus a few session records. The build window is short, and a broken code-generation step can block every coder at once.

## Decision

**Riverpod** (`flutter_riverpod`) is used for dependency injection and state, **without code generation**: providers are written by hand, and no `build_runner` step exists. Models are hand-written Dart classes with explicit `fromJson`/`toJson`.

Providers for interfaces throw `UnimplementedError` by default and are bound in the composition root (`modules/shell/src/app/`, rule R8). Tests use the same override mechanism with fakes.

## Rationale

Riverpod covers DI, state and test overrides with one tool and one wiring style for app, debug and tests. Avoiding code generation removes a whole class of build failures (stale generated files, generator version conflicts) during a deadline-driven build, and keeps diffs readable. With about ten models, hand-written serialization costs little.

## Alternatives Considered

- **Riverpod with `riverpod_generator`:** rejected because of the `build_runner` dependency.
- **`freezed` / `json_serializable`:** rejected for the same reason; the model count does not justify it.
- **Provider / InheritedWidget only:** rejected; weaker test overrides and no clean binding of interfaces.
- **GetIt service locator + a separate state library:** rejected as two tools for one job.
- **Bloc:** rejected as more ceremony for this team and app size.

## Implementation Details

- Each module declares providers in `src/<m>_providers.dart`, exported through `<m>.dart`.
- The composition root returns the production overrides (clock, location source, score factors, reminders, …).
- Long-lived subscriber controllers are started once in `AppStartup`, after content has loaded.
- Models live in `lib/modules/content/src/domain/models.dart` and module `domain/` folders; schema in `IMPLEMENTATION_PLAN.md` §3.

## Consequences

Serialization code is written and tested by hand; a schema change means editing the model and its test. There is no generated boilerplate to keep in sync.

## Validation

Unit tests cover model parsing against the dummy content fixtures; `tools/validate_content.py` validates the JSON independently of Dart.

## Risks

Hand-written `fromJson` can drift from the JSON schema; the content validator and model tests mitigate this.

## Follow-up

Revisit code generation only if the model count grows substantially.
