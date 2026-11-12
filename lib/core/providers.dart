import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core.dart';

/// Overridden with a `FakeClock` in tests and from the debug menu.
final clockProvider = Provider<Clock>((ref) => const SystemClock());

final eventBusProvider = Provider<EventBus>((ref) {
  final bus = EventBus();
  ref.onDispose(bus.dispose);
  return bus;
});

/// Persistent settings; in-memory until the composition root binds shared_preferences.
final keyValueStoreProvider =
    Provider<KeyValueStore>((ref) => MemoryKeyValueStore());
