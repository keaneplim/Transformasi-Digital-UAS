import 'package:shared_preferences/shared_preferences.dart';

import 'key_value_store.dart';

/// [KeyValueStore] on the device (shared_preferences, owned by core: R5).
class SharedPrefsStore implements KeyValueStore {
  SharedPrefsStore._(this._prefs);

  final SharedPreferencesWithCache _prefs;

  static Future<SharedPrefsStore> load() async =>
      SharedPrefsStore._(await SharedPreferencesWithCache.create(
          cacheOptions: const SharedPreferencesWithCacheOptions()));

  @override
  String? getString(String key) => _prefs.getString(key);

  @override
  Future<void> setString(String key, String value) =>
      _prefs.setString(key, value);
}
