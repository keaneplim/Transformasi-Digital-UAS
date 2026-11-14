import 'dart:convert';

import 'package:jelajah_taman/core/core.dart';

import '../domain/session_record.dart';

/// Keeps the running session and the last finished one on the device (PB06). Owns the
/// `session.*` keys of the [KeyValueStore] (rule R6); no other module reads them.
class SessionStore {
  SessionStore(this._kv);

  final KeyValueStore _kv;

  static const currentKey = 'session.current';
  static const lastKey = 'session.last';

  /// The session that was running when the app last stopped, if any.
  SessionRecord? loadCurrent() => _read(currentKey);

  /// The last finished session (summary, field-test evidence).
  SessionRecord? loadLast() => _read(lastKey);

  Future<void> save(SessionRecord r) => _write(currentKey, r);

  /// Moves [r] from "current" to "last". "Current" is cleared first, in the same call, so a
  /// session started right after this one (summary → new session) can't be wiped by it.
  Future<void> finish(SessionRecord r) async {
    final clear = _kv.setString(currentKey, '');
    await _write(lastKey, r);
    await clear;
  }

  SessionRecord? _read(String key) {
    final raw = _kv.getString(key);
    if (raw == null || raw.isEmpty) return null;
    try {
      return SessionRecord.fromJson(jsonDecode(raw) as Map<String, Object?>);
    } on Object catch (e) {
      // A record from an older build or a half-written value: drop it, don't crash.
      AppLog.info('Stored session $key unreadable, ignored: $e');
      return null;
    }
  }

  Future<void> _write(String key, SessionRecord r) async {
    try {
      await _kv.setString(key, jsonEncode(r.toJson()));
    } on Object catch (e) {
      AppLog.info('Could not save session $key: $e');
    }
  }
}
