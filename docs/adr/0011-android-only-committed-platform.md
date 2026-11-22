# 0011 Android Is the Only Committed Platform; Web and iOS Stay Local

Status: Accepted

Date: 2026-11-12

Scope: supported platforms, repository contents

## Context

The PRD targets Android (PRD §8.1, PB01: at least two Android test phones). Some team members use iPhones, which cannot install the APK. Flutter can also produce a web build (useful for quick UI previews on any laptop) and an iOS build (only on a Mac with Xcode, with a free Apple ID install that expires after 7 days). Supporting iOS properly would require background-location configuration, permission texts, different notification and audio setup, and running every test case twice.

## Decision

**Only `android/` is committed.** The `web/` and `ios/` platform folders may exist on individual machines for local use (browser preview, personal simulator or device runs) but stay untracked through `.git/info/exclude`. iOS remains **out of PRD scope**; iPhones are used for survey work (GPX recording, photos, reference readings), not as test devices.

## Rationale

The product and its acceptance tests are Android-only. Keeping other platforms local avoids reviewing and maintaining configuration that no requirement depends on, while still allowing quick previews.

## Alternatives Considered

- **Also ship iOS:** rejected; needs a Mac, paid or expiring signing, extra platform work and double testing (DEVICE_CHECK option B).
- **Commit `web/` for previews:** rejected; preview is a personal convenience, not a deliverable.

## Implementation Details

- `.git/info/exclude` lists `web/` and `ios/` on machines that create them.
- `flutter create` and `flutter analyze` may rewrite `analysis_options.yaml` and `.metadata`; those changes are reverted before committing.
- Local commands for web preview and iOS runs are kept per machine in `CLAUDE.local.md`.

## Consequences

Behaviour seen in a web preview or on iOS is not evidence for the PRD tests; acceptance testing happens on Android phones only.

## Validation

CI builds Android only; DEVICE_CHECK lists Android test phones.

## Risks

Platform differences can make a local web or iOS preview look correct while Android differs; final checks are always on Android.

## Follow-up

Record the two Android test phones in DEVICE_CHECK §3.
