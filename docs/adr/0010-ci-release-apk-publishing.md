# 0010 CI Builds a Release APK and Publishes It on the apk-latest Release

Status: Accepted (amended 2026-11-22)

Date: 2026-11-16

Scope: continuous integration, release distribution, APK signing

## Context

Team members, testers and lecturers need the latest app on Android phones without a local Android SDK; several laptops cannot build an APK. A debug APK is about 110 MB. There is no upload keystore, and the app is not distributed through the Play Store.

## Decision

The `build-apk` job in `.github/workflows/ci.yml` builds a **release APK for arm64-v8a** (`flutter build apk --release --target-platform android-arm64`) after the check job, on every pull request and push to `main`:

- on pull requests it only proves that the release build works and uploads a workflow artifact (14 days);
- on pushes to `main` it uploads the APK as `jelajah-taman.apk` to the **`apk-latest` GitHub Release** and moves the `apk-latest` tag to that commit.

**The APK is not committed to the repository.** The release is the single download location.

The APK is signed with the **CI runner's debug key**, deliberately; no upload keystore is introduced.

## Rationale

A release arm64 build is small and matches the test phones. A GitHub Release gives one stable link that is easy to open on a phone and is replaced on every push, so it costs nothing in git history. Debug signing keeps the pipeline free of secrets; the app is only installed by the team, testers and usability respondents for the duration of the course.

## Alternatives Considered

- **Debug APK:** rejected; about 110 MB and slower.
- **Commit the APK to the repository root on every push** (the original form of this decision): rejected on 2026-11-22; every build added tens of megabytes to git history and forced a `git pull` after each bot commit (PROGRESS #35).
- **Workflow artifacts only:** rejected; artifacts expire and require a GitHub login.
- **Stable upload keystore stored as a CI secret:** rejected; not needed for course distribution, and it adds secret management.
- **Play Store internal testing:** out of scope.

## Implementation Details

- The job fails if the APK exceeds the 95 MB size budget (A01).
- If `main` has moved on before publishing, the job skips publishing; the run for the newer commit publishes.
- Publishing step: read the version from `pubspec.yaml`, copy the APK to `jelajah-taman.apk`, force-move the `apk-latest` tag, then create or update the release with `--clobber` and release notes stating the version, commit, build time and the debug signing.
- `*.apk` and `jelajah-taman.apk` are listed in `.gitignore`.

## Consequences

- Download link: `https://github.com/keaneplim/Transformasi-Digital-UAS/releases/tag/apk-latest`.
- `main` no longer receives bot commits after a push.
- Every CI run signs with a different debug key, so installing a newer build over an older one can fail with a signature conflict; testers uninstall the previous version first, which clears local data (visited places, settings).
- Git history still contains the APK copies committed between 2026-11-16 and 2026-11-22; removing them would require rewriting history and is not done.

## Validation

CI runs on every push; the APK on the `apk-latest` release installs on the test phones.

## Risks

Signature conflicts between builds during field and usability testing; mitigated by installing one build per test round and uninstalling before updating.

## Follow-up

None planned.

## Amendment — 2026-11-22

The team confirmed the decision with two changes: the commit of `jelajah-taman.apk` to the repository root was removed (only the `apk-latest` release is kept, closing PROGRESS #35), and debug signing by CI is kept as the intended signing method rather than a temporary measure. The existing root `jelajah-taman.apk` was deleted from the repository and APK files are ignored.
