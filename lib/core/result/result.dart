/// Result of an operation that can fail in an expected way (e.g. a plugin adapter).
/// Domain code returns this instead of throwing for expected situations (ARCHITECTURE.md §9).
sealed class Result<T> {
  const Result();
}

final class Ok<T> extends Result<T> {
  const Ok(this.value);
  final T value;
}

final class Err<T> extends Result<T> {
  const Err(this.failure);
  final Failure failure;
}

class Failure {
  const Failure(this.code, [this.message]);

  /// Short machine-readable code, e.g. `permission_denied`, `gps_off`, `unknown_qr`.
  final String code;
  final String? message;

  @override
  String toString() => 'Failure($code${message == null ? '' : ': $message'})';
}
