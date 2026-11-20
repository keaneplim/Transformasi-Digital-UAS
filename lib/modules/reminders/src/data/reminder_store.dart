import 'dart:convert';

import 'package:jelajah_taman/core/core.dart';

/// Keeps the scheduler state of the running session (T23), so a restored session doesn't
/// repeat the closing reminder. Owns the `reminders.*` keys of the [KeyValueStore] (R6).
class ReminderStore {
  ReminderStore(this._kv);

  final KeyValueStore _kv;

  static const key = 'reminders.session';

  /// The stored state if it belongs to [sessionId], else null.
  Map<String, Object?>? load(String sessionId) {
    final raw = _kv.getString(key);
    if (raw == null || raw.isEmpty) return null;
    try {
      final json = jsonDecode(raw) as Map<String, Object?>;
      if (json['session'] != sessionId) return null;
      return json['state'] as Map<String, Object?>?;
    } on Object catch (e) {
      AppLog.info('Stored reminder state unreadable, ignored: $e');
      return null;
    }
  }

  Future<void> save(String sessionId, Map<String, Object?> state) async {
    try {
      await _kv.setString(
          key, jsonEncode({'session': sessionId, 'state': state}));
    } on Object catch (e) {
      AppLog.info('Could not save reminder state: $e');
    }
  }

  Future<void> clear() async {
    try {
      await _kv.setString(key, '');
    } on Object catch (e) {
      AppLog.info('Could not clear reminder state: $e');
    }
  }
}
