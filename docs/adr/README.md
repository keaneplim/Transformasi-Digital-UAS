# Architecture Decision Records

Durable technical decisions for Jelajah Taman. Each record explains the context, the decision, the alternatives that were rejected, and the consequences, so a developer can understand *why* without the original discussion.

Product decisions that change requirements are not ADRs: they live in the PRD (Change Log, §10) and in `docs/engineering/IMPLEMENTATION_PLAN.md` §1 (D01–D14).

| ADR | Title | Status | Date |
|---|---|---|---|
| [0001](0001-modular-monolith-with-folder-modules.md) | Modular monolith with folder modules and an import checker | Accepted | 2026-11-06 |
| [0002](0002-riverpod-without-code-generation.md) | Riverpod without code generation; hand-written models | Accepted | 2026-11-06 |
| [0003](0003-in-process-event-bus.md) | In-process event bus for domain events | Accepted | 2026-11-06 |
| [0004](0004-own-haversine-geofence.md) | Own haversine geofence instead of OS geofencing | Accepted | 2026-11-06 |
| [0005](0005-bundle-all-assets-in-the-apk.md) | Bundle map, content and audio in the APK | Accepted | 2026-11-06 |
| [0006](0006-single-isolate-and-foreground-service.md) | Single isolate with a geolocator foreground service | Accepted | 2026-11-06 |
| [0007](0007-open-closed-only-at-listed-extension-points.md) | Open/Closed only at listed extension points | Accepted | 2026-11-06 |
| [0008](0008-bundled-vector-basemap.md) | Bundled vector basemap instead of MBTiles raster tiles | Accepted | 2026-11-12 |
| [0009](0009-guide-controller-with-two-position-sources.md) | One GuideController with real and demo position sources | Accepted | 2026-11-12 |
| [0010](0010-ci-release-apk-publishing.md) | CI builds and publishes a release APK on every push to main | Accepted | 2026-11-16 |
| [0011](0011-android-only-committed-platform.md) | Android is the only committed platform; web and iOS stay local | Accepted | 2026-11-12 |
| [0012](0012-design-system-v2-sunlit-field-guide.md) | Design system v2 "Sunlit Field Guide" | Accepted | 2026-11-12 |

ADRs 0001–0009 were first written as a summary table in `docs/engineering/ARCHITECTURE.md` §12 (as ADR-001 … ADR-009) and split into these files on 2026-11-22. Older text that writes "ADR-008" refers to ADR 0008.

## Writing a new ADR

- File name `NNNN-kebab-case-title.md`, next free number; add a row above.
- Sections: Status, Date, Scope, Context, Decision, Rationale, Alternatives considered, Implementation details, Consequences, Validation, Risks, Follow-up.
- English, neutral and explanatory; written for developers, not as a record of a conversation.
- Extending a decision: add a dated *Amendment* section to the existing ADR. Reversing one: write a new ADR and set the old one to `Superseded by NNNN`.
