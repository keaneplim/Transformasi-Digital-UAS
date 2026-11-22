# 0010 CI Builds and Publishes a Release APK on Every Push to Main

Status: Accepted (team confirmation pending; see Follow-up)

Date: 2026-11-16

Scope: continuous integration, release distribution

## Context

Team members, testers and lecturers need the latest app on Android phones without a local Android SDK; several laptops cannot build an APK. A debug APK is about 110 MB, above GitHub's 100 MB file limit. There is no upload keystore yet.

## Decision

The `build-apk` job in `.github/workflows/ci.yml` builds a **release APK for arm64-v8a** (`flutter build apk --release --target-platform android-arm64`) after the check job, on every pull request and push to `main`:

- on pull requests it only proves that the release build works and uploads a workflow artifact (14 days);
- on pushes to `main` it commits the APK to the repository root as `jelajah-taman.apk` (bot commit `apk: release build of <sha> (v<version>, arm64) [skip ci]`) and uploads it to the `apk-latest` GitHub Release.

The APK is signed with the CI runner's debug key.

## Rationale

A release arm64 build fits below the file limit and matches the test phones. Publishing on every push to `main` means the newest build is always one download away, both in the repository and on the Releases page.

## Alternatives Considered

- **Debug APK:** rejected; over 100 MB.
- **Artifacts only:** rejected at the time; artifacts expire and require a GitHub login.
- **Release only, no commit:** viable and simpler for git history (see Risks).
- **Play Store internal testing:** out of scope for the course.

## Implementation Details

- The job fails if the APK exceeds 95 MB.
- If `main` has moved on before publishing, the job skips publishing; the newer run publishes.
- `paths-ignore: jelajah-taman.apk` prevents the bot commit from starting another run.
- Release notes state the version, commit, build time and that the app is debug-signed (uninstall the previous version on signature conflicts).

## Consequences

`main` receives a bot commit after each push, so contributors must `git pull` before new work. Every APK version stays in git history (tens of megabytes per build), growing the repository.

## Validation

CI runs on every push; the APK is installable from the repository root and the `apk-latest` release.

## Risks

Repository growth from committed binaries (PROGRESS #35). Debug signing means updates can conflict across CI runs with different keys.

## Follow-up

- Team to confirm the decision, or drop the commit step and keep only the `apk-latest` release (PROGRESS #35).
- Introduce a stable signing key before distributing to usability-test respondents.
