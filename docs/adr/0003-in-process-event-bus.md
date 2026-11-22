# 0003 In-Process Event Bus for Domain Events

Status: Accepted

Date: 2026-11-06

Scope: communication between modules

## Context

Several features react to the same moments: when a POI triggers, the app must post a notification, speak a prompt, optionally auto-play narration, log the visit, and highlight the map. Later features (recommendation, reminders, wellness) also react to session and visit events. If the publisher called each reaction directly, every new feature would edit already-tested code and create upward dependencies, which ADR 0001 forbids.

## Decision

Modules use **three channels**, each with one job:

| Channel | Used for |
|---|---|
| Direct call on a public interface | Questions and commands to a lower module |
| Stream on a public interface | High-frequency data (GPS fixes, audio state, steps) |
| Domain event on an in-process `EventBus` | Business news other modules may react to |

The event catalogue is deliberately short (E1–E10: session started/ended, POI approached/triggered/engaged/visited/finished, navigation started/arrived, reminder due) and is defined in `core/events/`. Events carry IDs and primitive values only.

## Rationale

Events make reactions additive: a new feature subscribes instead of editing the publisher, which keeps tested engines closed (see ADR 0007). Keeping data streams off the bus keeps the event log readable. A fixed, documented catalogue keeps the indirection understandable.

## Alternatives Considered

- **Direct calls for everything:** rejected; creates upward dependencies and edits to tested code for every new reaction.
- **Streams per module for news as well as data:** rejected; subscribers would depend on many modules' internals.
- **A message broker / isolate-based bus:** rejected as unnecessary for a single-process app (ADR 0006).

## Implementation Details

- `EventBus` in `lib/core/events/event_bus.dart`; event classes in `core/events/`.
- Adding an event requires a new row in ARCHITECTURE §5.2 in the same change. More than ~12 events is treated as a design smell.
- Every domain event is logged in debug builds.
- `NavigationArrived` (E9) is never consumed by `trigger` (decision D06).

## Consequences

Control flow is harder to trace than direct calls; this is mitigated by the fixed catalogue and debug logging. Subscribers must be started after their dependencies exist (`AppStartup`).

## Validation

Engine tests assert the events published for each state transition; subscriber tests feed events and assert reactions.

## Risks

Uncontrolled growth of the catalogue or events used to fetch data would erode the design; the catalogue rule and review guard against it.

## Follow-up

None planned.
