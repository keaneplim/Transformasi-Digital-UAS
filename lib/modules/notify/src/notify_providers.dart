import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/local_alert_notifier.dart';
import 'domain/alert_contracts.dart';

/// System notifications + vibration. Null until the composition root binds it (R8), so tests
/// and the web preview run without the plugin; the in-app card works either way.
final alertNotifierProvider = Provider<AlertNotifier?>((ref) => null);

/// Binding for the composition root. Initialises the plugin (channels, tap port, launch tap)
/// before the first frame, so a tap that cold-started the app isn't lost.
Future<Override> bindLocalAlertNotifier() async {
  final notifier = await LocalAlertNotifier.create();
  return alertNotifierProvider.overrideWith((ref) {
    ref.onDispose(notifier.dispose);
    return notifier;
  });
}
