# 0006 Single Isolate with a Geolocator Foreground Service

Status: Accepted

Date: 2026-11-06

Scope: background execution, process model

## Context

F01 requires location to keep updating while the screen is off during an active session, and F04 requires narration and controls on the lock screen. Android restricts background work aggressively. Multiple isolates or background engines would split state and the event bus (ADR 0003) across memory spaces.

## Decision

The app runs its logic in a **single Dart isolate**. Background location uses **one foreground service** provided by `geolocator` (with its persistent notification); audio uses the `audio_service` media service. No WorkManager and no background isolates, except the separate engine that Android uses for notification actions, which is bridged explicitly to the main isolate.

## Rationale

One isolate keeps one event bus and one state, which keeps the design simple and testable. A foreground service is the supported Android mechanism for continuous location during a user-visible activity.

## Alternatives Considered

- **Background isolate for tracking:** rejected; duplicated state and a second event bus.
- **WorkManager periodic jobs:** rejected; minimum intervals of ~15 minutes are far too coarse for geofencing.
- **OS geofencing in the background:** rejected in ADR 0004.

## Implementation Details

- Foreground tracking started with the session; stopped when the session ends.
- Notification action buttons run in a separate Flutter engine; actions are forwarded to the main isolate through `IsolateNameServer` (`notify` module).
- If the OS kills the app, the session is restored from storage on the next launch.

## Consequences

The session depends on the foreground service staying alive; aggressive OEM battery optimisations must be disabled on test phones (DEVICE_CHECK §1.5). The visible service notification is part of the experience.

## Validation

Phone tests with the screen locked (TC-06) and session restore after the app is killed.

## Risks

OEM-specific background killing; mitigated by device setup instructions and session restore.

## Follow-up

Verify background behaviour on at least two Android phones before the field test.
