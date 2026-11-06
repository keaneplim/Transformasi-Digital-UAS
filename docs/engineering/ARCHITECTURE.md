# ARCHITECTURE — Jelajah Taman

How the app's code is structured. This file explains **where code goes, what may depend on what, and how modules talk to each other**. It doesn't say what each feature does; that is in [IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md) (per feature) and the PRD (requirements).

**Style: modular monolith.** One Flutter app and one build, split into modules with enforced boundaries. Modules talk only through their public front door, via direct calls for questions and domain events for news. The Open/Closed principle is applied only where we already know things will vary (§6).

---

## 1. Why this shape

| Force | Consequence |
|---|---|
| Runs on one phone, no server (NG05), offline (A01) | One process, one deployable. No microservices, no backend, no network layer. |
| 3 coders, ~3 weeks of build time, AI-assisted coding | Boundaries must be **mechanically enforced**, or they erode by Sprint 4. Ownership maps to modules so people rarely edit the same files. |
| Most of the risk is logic (geofence, routing, recommendation, reminders), and the PRD already had logic bugs (#8–#12) | That logic lives in **pure Dart**, so it can be unit-tested without a phone, GPS, or Tahura. |
| Plugins (GPS, audio, TTS, notifications) are the most fragile part on Android | Each plugin hides behind **one thin adapter** per module. A plugin problem stays in one file. |
| Features keep being added until the S4 feature freeze (recommendation, reminders, wellness) | New behaviour should be **added** (a new subscriber or a new strategy), not edited into code that is already tested. That is the Open/Closed principle where it pays off. |

What we deliberately **don't** do: a separate Dart package per module, Clean Architecture with one use-case class per action, a runtime plugin system, or code generation. Each costs more ceremony than it returns at 15 screens and 3 people. ADRs in §12 record these choices.

---

## 2. The rules (non-negotiable)

1. **R1 — Public front door.** Every module has exactly one public file, `lib/modules/<m>/<m>.dart`. Other modules import **only** that file, never `lib/modules/<m>/src/...`.
2. **R2 — Dependencies point downward.** A module may depend only on modules at a **lower level** (§4). No cycles. If you need something from a higher level, publish an event instead.
3. **R3 — Questions = calls, news = events.** Ask another module for data through its public interface. Announce that something happened by publishing a domain event. Never use events to fetch data, and never call "upward" to notify.
4. **R4 — Domain is pure.** `src/domain/` imports only `dart:*`, `core`, and other modules' public files. No `package:flutter`, no plugins. This is what makes the logic testable in milliseconds.
5. **R5 — Plugins only in adapters.** A plugin package (geolocator, just_audio, flutter_tts, sqflite, mobile_scanner, …) is imported **only** in `src/data/` of the module that owns it. Exactly one module owns each plugin (§3).
6. **R6 — Own your tables.** Each module owns its database tables and its keys in SharedPreferences. No module reads another module's tables; it asks through the public API.
7. **R7 — Time comes from `Clock`.** Never call `DateTime.now()` outside `core/clock`. This is required for the closing-time test (TC-10) and every reminder test.
8. **R8 — Wiring happens in one place.** Implementations are bound in the composition root (`modules/shell/src/app/`). Modules expose providers; they don't construct each other.

R1, R2, R5 and R7 are checked by `tools/check_architecture.dart` (§10) on every PR. A PR that fails the check is not reviewed.

---

## 3. Module catalogue

| Level | Module | Owner | Responsibility | Owns plugin / tables |
|---|---|---|---|---|
| 0 | `core` | A (+all) | Shared kernel: `Clock`, geo maths, `EventBus` + event definitions, DB handle, logging, `Result`/failure types, theme tokens. **No feature logic.** | `sqflite` (connection only), `shared_preferences` |
| 1 | `content` | C | Load and validate the JSON assets: POIs, facilities, routes, park config, trail graph. Immutable models. | — (assets) |
| 1 | `location` | A | GPS fixes, GPS quality, foreground tracking, interval switching (A06), GPX replay source. | `geolocator`; table `activity_samples` |
| 1 | `audio` | C | Narration playback, TTS, `VoiceArbiter` (priority/duck/queue), media session for the lock screen. | `just_audio`, `audio_service`, `flutter_tts` |
| 1 | `notify` | C | Notification channels, posting, action callbacks, vibration patterns. | `flutter_local_notifications`, `vibration` |
| 2 | `routing` | B | Trail graph, snapping, Dijkstra, ETA with slope, turn instructions. Pure logic plus the graph from `content`. | — |
| 2 | `trigger` | A | Geofence state machine, debounce/hysteresis/cooldown, QR + manual triggers, trigger notification, UI04/UI05/UI12, QR scanner. | `mobile_scanner`; table `visit_events` |
| 3 | `session` | A | Session lifecycle (start/end/restore), session log (triggered vs visited), session metrics. | table `sessions` |
| 3 | `map` | B | Explore map (UI03), tile layer, marker/ring/route layers. | MBTiles provider, `flutter_map` |
| 3 | `navigation` | B | Active navigation, progress, off-route → reroute, arrival, UI10/UI11. | — |
| 3 | `poi` | C | POI Detail screen (UI06), gallery, player widget. Publishes engagement events. | — |
| 4 | `search` | B | Search matching + UI09. | — |
| 4 | `recommendation` | A | Candidate filter, `ScoreFactor` scoring, UI08. | — |
| 4 | `reminders` | A (closing) / C (hydration) | `ReminderScheduler` + `Reminder` implementations, UI13. | — |
| 4 | `wellness` | C | Route chooser data, pedometer, distance/kcal, summary UI14. | `pedometer` |
| 5 | `shell` | C (+A for wiring) | App entry, composition root, routing table (go_router), onboarding UI01, Home UI02, Settings UI15, debug menu. | `go_router`, `permission_handler` |

**Ownership ≠ exclusivity.** Anyone may open a PR anywhere, but the owner reviews changes to their module.

---

## 4. Dependency graph

```
L5  shell ───────────────────────────────── may use everything below
          │
L4  search   recommendation   reminders   wellness
          │         │             │           │
L3  session      map        navigation      poi
          │         │             │           │
L2  trigger ─────────────── routing
          │                       │
L1  location    audio    notify    content
          │         │        │        │
L0  ─────────────────── core ──────────────────
```

**Allowed dependencies** (a ✔ means the row may import the column's public file):

| ↓ uses → | core | content | location | audio | notify | routing | trigger | session | map | navigation | poi |
|---|---|---|---|---|---|---|---|---|---|---|---|
| content | ✔ | | | | | | | | | | |
| location | ✔ | ✔ | | | | | | | | | |
| audio | ✔ | ✔ | | | | | | | | | |
| notify | ✔ | | | | | | | | | | |
| routing | ✔ | ✔ | | | | | | | | | |
| trigger | ✔ | ✔ | ✔ | ✔ | ✔ | | | | | | |
| session | ✔ | ✔ | ✔ | | | | ✔ | | | | |
| map | ✔ | ✔ | ✔ | | | ✔ | ✔ | | | | |
| navigation | ✔ | ✔ | ✔ | ✔ | | ✔ | | | | | |
| poi | ✔ | ✔ | ✔ | ✔ | | ✔ | | | | | |
| search | ✔ | ✔ | ✔ | | | ✔ | | | | | |
| recommendation | ✔ | ✔ | ✔ | | ✔ | ✔ | | ✔ | | | |
| reminders | ✔ | ✔ | ✔ | ✔ | ✔ | ✔ | | ✔ | | | |
| wellness | ✔ | ✔ | ✔ | | | ✔ | | ✔ | | | |
| shell | ✔ all | | | | | | | | | | |

Same-level imports (e.g., `map` → `navigation`) are **not allowed**. When two same-level modules need to cooperate, the higher module (`shell`) composes them in a screen, or they communicate through events. Example: the Explore screen in `shell` places the `map` widget and the `navigation` overlay together.

If you think you need a new arrow, raise it in the PR description. Adding an arrow means updating this table **and** the checker config, in the same PR.

---

## 5. Communication

### 5.1 Three channels, each with one job

| Channel | Use for | Example |
|---|---|---|
| **Direct call** through the public interface | Questions (synchronous or `Future`) and commands to a lower module | `router.walkingTime(pos, 'N_P01')`, `audio.playNarration('P05')` |
| **Stream** on a public interface | High-frequency **data** (several times a second down to every few seconds) | `locationService.fixes`, `audio.state`, `pedometer.steps` |
| **Domain event** on `EventBus` | Business **news** that other modules may react to; the publisher doesn't know who listens | `PoiTriggered`, `SessionEnded` |

GPS fixes are **not** events on the bus: they are data with a frequency, and putting them on the bus would make the event log useless.

### 5.2 Event catalogue (the whole list — keep it short)

Events carry **IDs and primitive values only**, never module-internal types. They are defined in `core/events/` because they are the shared language between modules.

| # | Event | Payload | Published by | Subscribed by |
|---|---|---|---|---|
| E1 | `SessionStarted` | sessionId, routeId?, interests | session | trigger (reset), wellness (step baseline), reminders (start), location (if not called directly) |
| E2 | `SessionEnded` | sessionId | session | reminders (stop), wellness (finalize), trigger (persist) |
| E3 | `PoiApproached` | poiId, distanceM | trigger | notify-reaction in trigger (vibrate), map (pulse ring) |
| E4 | `PoiTriggered` | poiId, source (gps/qr/manual) | trigger | trigger (post notification), audio (voice prompt, Auto-Play), session (log), map (halo) |
| E5 | `PoiEngaged` | poiId, how (opened/listened/autoplay/qr/nav) | poi, audio, trigger (QR), navigation (UI11 *Buka detail*) | trigger (→ Visited state, D05) |
| E6 | `PoiVisited` | poiId, source | trigger | session (visited log), map (check badge), recommendation (mark) |
| E7 | `PoiFinished` | poiId, reason (detailClosed/narrationDone/leftArea) | poi, audio, trigger | recommendation (compute next, ≤2 s) |
| E8 | `NavigationStarted` | destinationId | navigation | map (draw route), reminders (optional) |
| E9 | `NavigationArrived` | destinationId, isPoi | navigation | audio (announce), shell (UI11) — **never** trigger (D06) |
| E10 | `ReminderDue` | kind (closing/hydration/finalCall), text, actionDestinationId? | reminders | audio (speak, priority by kind), notify (post) |

**Rule:** adding an event requires a row here, in the same PR. If the list grows past ~12 events, that is a design smell: stop and review.

This is where the Open/Closed principle earns its keep. `TriggerEngine` publishes E4 and is **closed**: it was unit-tested in S2. Voice prompt, Auto-Play, notification, session logging and the map halo are subscribers. In S4, recommendation is just another subscriber to E7. The engine file isn't touched.

### 5.3 EventBus (in `core/events/event_bus.dart`)
```dart
abstract class DomainEvent {
  DomainEvent(this.at);
  final DateTime at;               // from Clock, never DateTime.now()
}

class EventBus {
  final _controller = StreamController<DomainEvent>.broadcast();
  void publish(DomainEvent e) {
    assert(() { AppLog.event(e); return true; }());   // every event logged in debug
    _controller.add(e);
  }
  Stream<T> on<T extends DomainEvent>() => _controller.stream.where((e) => e is T).cast<T>();
  Future<void> dispose() => _controller.close();
}
```
- **Async delivery** (default broadcast): a subscriber can't block or crash the publisher. Subscribers must catch their own errors and log them.
- **Single isolate.** The whole app (including screen-off tracking via geolocator's foreground notification) runs in the main isolate, so one bus is enough. The exception is notification action callbacks that run in a background isolate (F04 spike, R8). They must forward into the main isolate (e.g., via `IsolateNameServer`/`SendPort`) and publish there, never touch the bus directly.

---

## 6. Open/Closed: where and how

Apply it **only** at these extension points. Everywhere else, write a plain concrete class. You extract an interface when a second implementation actually exists, not before.

| Extension point | Interface (module) | Implementations | Added later without editing existing code |
|---|---|---|---|
| Position source | `LocationSource` (location) | `GeolocatorSource`, `GpxReplaySource`, `TeleportSource` (debug) | e.g., a recorded-log source for field-test replays |
| Time | `Clock` (core) | `SystemClock`, `FakeClock` | — |
| Trigger entry | `TriggerEngine.onFix / onQrScanned / onManualPick` (trigger) | GPS, QR, manual | another fallback (NG03 forbids BLE now, but the seam exists) |
| Reactions to news | `EventBus` subscribers | notification, voice, Auto-Play, log, halo, recommendation | any new reaction = a new subscriber |
| Recommendation scoring | `ScoreFactor` (recommendation) | distance, interest, route, difficulty | e.g., "rest point nearby" factor; weight from `park.json` |
| Reminders | `Reminder` (reminders) | `ClosingReminder`, `HydrationReminder`, `FinalCallReminder` | e.g., "museum closes soon" |
| Narration source | `NarrationSource` (audio) | `RecordedNarration`, `TtsNarration` | — |
| Turn phrasing | `InstructionPhraser` (routing) | Indonesian template | — (NG08: Indonesian only) |

### 6.1 Example — `ScoreFactor`
```dart
abstract interface class ScoreFactor {
  String get id;                                   // matches key in park.json rec_weights
  double score(Poi candidate, RecContext ctx);     // 0..1
  String? reason(Poi candidate, RecContext ctx);   // "Sesuai minat Sejarah" or null
}

class Recommender {
  Recommender(this._factors, this._weights);       // injected; Recommender never names a factor
  final List<ScoreFactor> _factors;
  final Map<String, double> _weights;
  double total(Poi c, RecContext ctx) =>
      _factors.fold(0, (s, f) => s + (_weights[f.id] ?? 0) * f.score(c, ctx));
}
```
Adding a factor means one new class plus one line in the composition root plus one weight in JSON. `Recommender` and its tests are not edited.

### 6.2 Example — `Reminder`
```dart
abstract interface class Reminder {
  ReminderKind get kind;
  /// Return the event to publish now, or null. Called every tick (60 s) and on significant moves.
  ReminderDue? check(ReminderContext ctx);   // ctx: now, last fix, session start, settings, router
}
class ReminderScheduler { /* holds List<Reminder>; on tick → publish non-null results; dedupes "once per session" */ }
```

---

## 7. Inside a module

### 7.1 Template
```
lib/modules/<m>/
  <m>.dart                 PUBLIC: exports interfaces, models, providers, widgets other modules may use
  src/
    domain/                pure Dart: entities, value objects, state machines, algorithms, interfaces (ports)
    data/                  adapters: plugin wrappers, DB tables, JSON parsing (implements domain ports)
    application/           controllers / notifiers: orchestrate domain + adapters, subscribe to events
    ui/                    screens and widgets (Flutter)
    <m>_providers.dart     Riverpod providers for this module (exported via <m>.dart)
test/modules/<m>/          mirrors src/; domain tests need no Flutter binding
```
Not every module needs all four folders: `routing` is almost all `domain/`, `shell` is mostly `ui/`. Don't create empty folders.

### 7.2 Worked example — `trigger`
```
lib/modules/trigger/
  trigger.dart                       export TriggerEngine (interface), PoiState, TriggerSource, triggerEngineProvider,
                                     QrScannerScreen, ManualPickSheet, GpsWeakBanner
  src/domain/
    poi_state_machine.dart           per-POI state, debounce, hysteresis, cooldown (pure)
    trigger_engine.dart              evaluates all eligible POIs per fix (D01), returns List<DomainEvent>
    qr_payload.dart                  parse "jelajahtaman://poi/P05"
  src/data/
    visit_event_table.dart           owns table visit_events
    trigger_state_store.dart         persist/restore engine state (session restore)
  src/application/
    trigger_controller.dart          subscribes location.fixes → engine → publishes events; listens E5 → Visited
    trigger_notification_reaction.dart  subscribes E4 → notify.post(...) with actions Dengarkan/Lihat/Nanti
    approach_haptic_reaction.dart    subscribes E3 → notify.vibrate(approachPattern)
  src/ui/
    approaching_banner.dart  qr_scanner_screen.dart  manual_pick_sheet.dart  gps_weak_banner.dart
  src/trigger_providers.dart
```
Note the split: `trigger_engine.dart` **returns** events (pure, testable with a table of fixes). `trigger_controller.dart` **publishes** them. The engine never sees the bus, plugins, or Flutter.

---

## 8. Composition root & state management

- **Riverpod** (`flutter_riverpod`, **no code generation**: hand-written providers, no `build_runner`). Models are hand-written with `fromJson` too. There are ~10 models, so freezed/json_serializable aren't worth the build step.
- Each module declares its providers in `src/<m>_providers.dart`, exported through `<m>.dart`. Providers for **interfaces** throw `UnimplementedError` by default and are bound in the composition root:

```dart
// modules/shell/src/app/composition_root.dart
List<Override> productionOverrides(AppConfig cfg) => [
  clockProvider.overrideWithValue(cfg.fakeClock ?? SystemClock()),
  locationSourceProvider.overrideWith((ref) =>
      cfg.gpxReplayFile != null ? GpxReplaySource(cfg.gpxReplayFile!) : GeolocatorSource()),
  scoreFactorsProvider.overrideWithValue([DistanceFactor(), InterestFactor(), RouteFactor(), DifficultyFactor()]),
  remindersProvider.overrideWithValue([ClosingReminder(), HydrationReminder()]),
];
```
- Tests use the same mechanism with fakes, so there is one wiring style for app, debug and tests.
- Long-lived "reaction" controllers (subscribers) are started in one place, `AppStartup`, after the content has loaded, so nothing subscribes before its dependencies exist.
- Navigation between screens: `go_router` table in `shell`. A module exposes **route builders**, and `shell` registers them. Modules never `push` a route owned by another module directly; they call a callback or go through `shell`'s named routes (`/poi/:id`, `/navigate/:dest`).

---

## 9. Cross-cutting concerns

| Concern | Rule |
|---|---|
| **Errors** | Adapters catch plugin exceptions and return `Result<T, Failure>` (in `core`) or emit a degraded state (e.g., `GpsQuality.none`). Domain code doesn't throw for expected situations. UI maps failures to Indonesian messages. Unexpected exceptions go to `FlutterError.onError` + `PlatformDispatcher.onError` → `AppLog.error`. |
| **Logging** | `AppLog` in `core` (levels: debug/info/event/error). Every domain event is logged in debug builds. Field-test evidence goes to DB tables, not to logs. |
| **Persistence** | One `Database` from `core`; each module registers its own table migrations (`registerMigrations(m)`) at startup. Schema version in one place. |
| **Configuration** | All tunables come from `content`'s `ParkConfig` (`park.json`). No magic numbers in domain code. Pass config in through constructors so tests can vary it. |
| **Permissions** | Requested only in `shell` (onboarding) through `permission_handler`. Modules check status through a tiny `PermissionsGateway` interface in `core`, and never prompt themselves (camera is the one in-context exception, prompted by `shell` when the scanner route opens). |
| **Background** | One foreground service (location, via geolocator) plus the `audio_service` media service. No WorkManager and no background isolates except the notification-action bridge (§5.3). If the OS kills the app, the session is restored from DB on next launch. |
| **Theming** | DESIGN.md tokens as one `ThemeData` + `ThemeExtension` in `core/theme`. Widgets don't hard-code colours. |
| **Localization** | Indonesian only (NG08). Strings live in one `strings_id.dart` per module rather than inline, so copy review is one file per module. |

---

## 10. Enforcement

### 10.1 `tools/check_architecture.dart` (run locally and in CI)
Checks every `.dart` file under `lib/modules/`:
1. **R1:** no import of `package:jelajah_taman/modules/<other>/src/...`.
2. **R2:** an import of another module's public file must be allowed by the §4 table (the table lives in the script as a `Map<String, Set<String>>`).
3. **R5:** plugin packages are imported only from the owning module's `src/data/` (map of package → module).
4. **R4:** no `package:flutter/` import inside any `src/domain/`.
5. **R7:** no `DateTime.now()` outside `lib/core/clock/`.

```dart
// tools/check_architecture.dart (outline; ~80 lines when written)
const allowed = <String, Set<String>>{
  'content': {'core'},
  'location': {'core', 'content'},
  'trigger': {'core', 'content', 'location', 'audio', 'notify'},
  // … exactly the §4 table …
};
const pluginOwner = {'geolocator': 'location', 'just_audio': 'audio', 'flutter_tts': 'audio',
  'audio_service': 'audio', 'flutter_local_notifications': 'notify', 'vibration': 'notify',
  'mobile_scanner': 'trigger', 'pedometer': 'wellness', 'flutter_map': 'map', 'go_router': 'shell'};
void main() { /* walk lib/, regex imports, report "file:line rule message", exit(1) on any violation */ }
```

### 10.2 CI (GitHub Actions, on every PR to `main`)
`flutter pub get` → `dart format --set-exit-if-changed .` → `flutter analyze` → `dart run tools/check_architecture.dart` → `flutter test` → `python tools/validate_content.py`. Branch protection: CI green and 1 approving review required to merge.

### 10.3 Lints
`analysis_options.yaml` with `flutter_lints` plus: `avoid_dynamic_calls`, `prefer_final_locals`, `unawaited_futures`, `always_declare_return_types`, `avoid_print` (use `AppLog`).

---

## 11. Testing architecture

| Layer | Test type | Needs | Speed |
|---|---|---|---|
| `domain/` | Plain `test` (no Flutter binding) | Fixtures: fixes, graphs, fake clock | ms |
| `application/` | `test` with a real `EventBus` + fake adapters via provider overrides | — | ms |
| `data/` | Few tests: JSON parsing, DB migrations (`sqflite_common_ffi`) | — | fast |
| `ui/` | Widget tests only for critical screens (UI05 actions, UI06 player, UI09 search) | — | s |
| Whole app | Manual on device with GPX replay + fake clock (debug menu); field TCs | phone | min |

Required test files (they gate merging): trigger engine (9 cases in IMPLEMENTATION_PLAN F02), Dijkstra/snapping/ETA/turns, search matching, recommender (filter + factors + back-to-gate), reminders (closing once/late/moving threshold, hydration interval), voice arbiter, content validation.

---

## 12. Architecture Decision Records (ADR)

Short records; add one when a decision would surprise a newcomer. Format: *context → decision → consequence*.

| ADR | Decision | Why / trade-off |
|---|---|---|
| 001 | Modular monolith, modules as **folders** with a checker, not separate packages | Same boundaries at far less tooling cost; can be promoted to a pub workspace later because the boundaries already match. |
| 002 | Riverpod, **no codegen**; hand-written models | DI + state + test overrides in one tool; no `build_runner` breaking builds under deadline. |
| 003 | In-process `EventBus` for ~10 domain events; calls for queries; streams for high-frequency data | Open/Closed reactions without coupling; cost = harder tracing, mitigated by a fixed catalogue and debug logging. |
| 004 | Own haversine geofence, not the OS geofencing API | PRD §4.2: debounce/hysteresis/cooldown must be controllable and testable. |
| 005 | All map/content/audio assets **bundled** in the APK | No failed download at the gate; larger APK (budget in IMPLEMENTATION_PLAN A01). |
| 006 | Single isolate; foreground service via geolocator | One bus, simple state; notification-action isolate bridged explicitly. |
| 007 | Open/Closed only at the extension points listed in §6 | Avoids interface-per-class bloat; new interfaces need a second implementation to justify them. |

---

## 13. How to add something (checklist)

**New feature inside an existing module**
1. Domain logic in `src/domain/` with tests first.
2. Adapter in `src/data/` if a plugin or table is involved (only if your module owns that plugin).
3. Controller in `src/application/`; publish or subscribe events from §5.2.
4. UI in `src/ui/`; export only what others need via `<m>.dart`.
5. Run `tools/check_architecture.dart` + tests; open a PR, reviewed by the module owner.

**New reaction to something that happens** → a new subscriber class in the module that owns the *reaction's* meaning. Don't edit the publisher.

**New module** → justify it in the PR, add a row to §3 and an entry to the §4 table, and update the checker map. Prefer extending an existing module unless the new responsibility has its own owner and its own data.

**New dependency arrow** → update §4 and the checker in the same PR, and explain in the PR why an event wasn't enough.
