import 'dart:async';
import 'package:jelajah_taman/core/core.dart';
import 'package:jelajah_taman/modules/location/location.dart';
import 'package:jelajah_taman/modules/trigger/src/domain/trigger_engine.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TriggerController {
  final TriggerEngine _engine;
  final LocationService _locationService;
  final EventBus _eventBus;
  
  StreamSubscription<LocationFix>? _fixSub;
  StreamSubscription<PoiEngaged>? _engagedSub;

  TriggerController(this._engine, this._locationService, this._eventBus) {
    _init();
  }

  void _init() {
    // 1. Listen to location fixes and feed the engine
    _fixSub = _locationService.fixes.listen((fix) {
      final events = _engine.processFix(fix);
      for (final event in events) {
        _eventBus.publish(event);
      }
    });

    // 2. Listen to PoiEngaged to mark POIs as Visited (D05)
    _engagedSub = _eventBus.on<PoiEngaged>().listen((event) {
      _engine.markVisited(event.poiId); // Engine updates internal state to PoiState.visited
      _eventBus.publish(PoiVisited(poiId: event.poiId, at: Clock.now()));
    });
  }

  void dispose() {
    _fixSub?.cancel();
    _engagedSub?.cancel();
  }
}

// Riverpod Provider for UI04 (Approaching Banner)
final approachingPoiProvider = StreamProvider<PoiApproached>((ref) {
  final eventBus = ref.watch(eventBusProvider);
  return eventBus.on<PoiApproached>();
});