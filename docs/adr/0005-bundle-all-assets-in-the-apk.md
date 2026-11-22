# 0005 Bundle Map, Content and Audio in the APK

Status: Accepted

Date: 2026-11-06

Scope: offline mode (A01), asset delivery, APK size

## Context

Cellular signal inside Tahura Djuanda is unreliable, and A01 requires the full F01–F08 flow to work in airplane mode (TC-13). The PRD scenario allows a one-time download at the start, but a download at the park gate can fail on a weak connection, and there is no server to host content (NG05).

## Decision

All map data, content JSON, photos, narration audio and the trail graph are **bundled as Flutter assets in the APK**. There is no first-run download.

## Rationale

Bundling removes the failure mode of a download at the gate and the need for any hosting. The app works immediately after install, which also simplifies field testing.

## Alternatives Considered

- **Download once on first launch:** rejected; needs hosting and fails on weak signal.
- **Stream content online with caching:** rejected; violates A01.
- **Android Play Asset Delivery:** rejected; requires Play Store distribution, which is out of scope.

## Implementation Details

- Assets: `assets/content/`, `assets/images/`, `assets/audio/`, `assets/map/`, `assets/fonts/` (declared in `pubspec.yaml`).
- Map data uses a compact vector basemap (ADR 0008) to keep the APK small.
- The only online feature is the optional satellite map layer, which degrades gracefully without internet.

## Consequences

A larger APK (the release arm64 build is in the tens of megabytes) and a new build for every content change. The size budget is tracked in IMPLEMENTATION_PLAN A01 and enforced in CI below GitHub's 100 MB file limit (ADR 0010).

## Validation

TC-05 and TC-13 in airplane mode; CI fails the release build if the APK exceeds 95 MB.

## Risks

Audio and photos dominate the size; adding long narration or high-resolution photos can push the APK toward the limit.

## Follow-up

Monitor APK size as final photos and audio are added.
