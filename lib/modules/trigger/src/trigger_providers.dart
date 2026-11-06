import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'domain/trigger_contracts.dart';

// TODO(A): pure engine in src/domain/, controller that publishes events in src/application/.
final triggerEngineProvider = Provider<TriggerEngine>(
  (ref) => throw UnimplementedError('triggerEngineProvider not bound yet'),
);
