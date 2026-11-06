// ignore_for_file: avoid_print

/// Minimal app logger. Use this instead of `print` (lint `avoid_print`).
/// Field-test evidence goes to the database, not to logs (ARCHITECTURE.md §9).
class AppLog {
  AppLog._();

  static const bool _release = bool.fromEnvironment('dart.vm.product');

  static void debug(String message) {
    if (!_release) print('[D] $message');
  }

  static void info(String message) => print('[I] $message');

  /// Every domain event is logged in debug builds (ARCHITECTURE.md §5.3).
  static void event(Object event) {
    if (!_release) print('[E] $event');
  }

  static void error(String message, [Object? error, StackTrace? stackTrace]) {
    print('[X] $message${error == null ? '' : ' — $error'}');
    if (stackTrace != null) print(stackTrace);
  }
}
