import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core.dart';

/// Overridden with a `FakeClock` in tests and from the debug menu.
final clockProvider = Provider<Clock>((ref) => const SystemClock());

final eventBusProvider = Provider<EventBus>((ref) {
  final bus = EventBus();
  ref.onDispose(bus.dispose);
  return bus;
});
