/// Shared kernel (level 0). Pure Dart — safe to import from any `src/domain/`.
///
/// No feature logic belongs here. Flutter-dependent core pieces are imported directly:
/// `core/providers.dart` (Riverpod) and `core/theme/app_theme.dart` (Material).
library;

export 'clock/clock.dart';
export 'events/event_bus.dart';
export 'events/events.dart';
export 'geo/geo.dart';
export 'log/app_log.dart';
export 'prefs/key_value_store.dart';
export 'result/result.dart';
