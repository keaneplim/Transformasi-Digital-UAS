import 'dart:async';

import '../log/app_log.dart';
import 'events.dart';

/// In-process bus for domain events (ARCHITECTURE.md §5.3, ADR-003).
///
/// Delivery is asynchronous: a subscriber can't block or crash the publisher.
/// Subscribers must catch and log their own errors.
/// Main isolate only — background isolates must forward into the main isolate first.
class EventBus {
  final StreamController<DomainEvent> _controller =
      StreamController<DomainEvent>.broadcast();

  void publish(DomainEvent event) {
    AppLog.event(event);
    _controller.add(event);
  }

  Stream<T> on<T extends DomainEvent>() =>
      _controller.stream.where((e) => e is T).cast<T>();

  Future<void> dispose() => _controller.close();
}
