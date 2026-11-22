# 0007 Open/Closed Only at Listed Extension Points

Status: Accepted

Date: 2026-11-06

Scope: abstraction policy, interfaces

## Context

Features keep arriving until the S4 feature freeze (recommendation factors, reminder kinds, location sources). New behaviour should be added without editing code that is already tested. On the other hand, an interface for every class adds indirection and boilerplate with no benefit when there is only one implementation.

## Decision

The Open/Closed principle is applied **only at the extension points listed in ARCHITECTURE §6**, where variation is already known (for example `ScoreFactor` for recommendation scoring, `Reminder` for reminder kinds, the location source for real/replay/demo positions) and through event subscribers (ADR 0003). Elsewhere, concrete classes are used.

A new interface needs a second real implementation (tests do not count) to justify it.

## Rationale

This captures the benefit of extensibility where it is known to pay off and avoids interface-per-class bloat elsewhere.

## Alternatives Considered

- **Interface for every service:** rejected as boilerplate.
- **No abstractions:** rejected; recommendation and reminders were known to grow by adding kinds.

## Implementation Details

- Extension points and worked examples: ARCHITECTURE §6.1 (`ScoreFactor`) and §6.2 (`Reminder`).
- Implementations are registered in the composition root (ADR 0002).
- Example of a deliberately concrete class: `ContentRepository` (one implementation).

## Consequences

Adding a recommendation factor or reminder kind is a new class plus a registration. Changing a concrete class may later require extracting an interface when a second implementation appears.

## Validation

Review against ARCHITECTURE §6; tests for each implementation.

## Risks

Extension points chosen too early or too late; reviewed when new variation appears.

## Follow-up

None planned.
