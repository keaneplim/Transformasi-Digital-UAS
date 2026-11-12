/// Small persistent settings (app mode, later preferences). Pure Dart interface; the
/// shared_preferences implementation lives in `shared_prefs_store.dart` and is bound in the
/// composition root (R8). Tests use [MemoryKeyValueStore].
abstract interface class KeyValueStore {
  String? getString(String key);

  Future<void> setString(String key, String value);
}

class MemoryKeyValueStore implements KeyValueStore {
  MemoryKeyValueStore([Map<String, String>? initial]) : _values = {...?initial};

  final Map<String, String> _values;

  @override
  String? getString(String key) => _values[key];

  @override
  Future<void> setString(String key, String value) async =>
      _values[key] = value;
}
