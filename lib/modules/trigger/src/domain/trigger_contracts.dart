import 'package:jelajah_taman/core/core.dart';

enum PoiState { outside, approaching, triggered, visited, cooldown }

/// Trigger sources use `TriggerSource` from core/events (gps, qr, manual).
/// Implementation: `GeofenceEngine` (pure Dart, F02).
abstract interface class TriggerEngine {
  Map<String, PoiState> get states;

  /// Jumps straight to Triggered + Visited (PRD §4.2).
  List<DomainEvent> qr(String poiId, DateTime now);

  /// Manual pick: Triggered.
  List<DomainEvent> manual(String poiId, DateTime now);
}
