import 'package:jelajah_taman/core/core.dart';
import 'package:jelajah_taman/modules/content/content.dart';
import 'package:jelajah_taman/core/models/location_models.dart';

class PoiTriggerContext {
  PoiState state = PoiState.outside;
  int debounceCount = 0;
  DateTime? triggeredAt;
  bool leftRetriggerZone = false;
  bool approachBuzzed = false;
}

class TriggerEngine {
  final Map<String, PoiTriggerContext> _poiContexts = {};
  final ContentRepository _content;
  final Clock _clock;

  TriggerEngine(this._content, this._clock) {
    for (final poi in _content.pois) {
      if (poi.category != 'fasilitas' && poi.id != _content.park.gatePoiId) {
        _poiContexts[poi.id] = PoiTriggerContext();
      }
    }
  }

  Map<String, PoiState> get states => 
      _poiContexts.map((key, value) => MapEntry(key, value.state));

  /// Process a new location fix to update POI states. Returns a list of events to publish.
  List<Object> processFix(LocationFix fix) {
    final events = <Object>[];
    
    // Ignore weak fixes for trigger logic (PROPOSED in D08/F02)
    if (fix.accuracyM > _content.park.param('gps_weak_accuracy_m')) {
      return events;
    }

    final approachMargin = _content.park.param('approach_margin_m').toDouble();
    final approachExitMargin = _content.park.param('approach_exit_margin_m').toDouble();
    
    // 1. Update states and find candidates
    List<MapEntry<Poi, double>> triggerCandidates = [];

    for (final poi in _content.pois) {
      if (!_poiContexts.containsKey(poi.id)) continue;
      
      final ctx = _poiContexts[poi.id]!;
      final distance = haversineM(fix.position, poi.position);
      final radius = poi.radiusM.toDouble();

      // Handle Approaching Hysteresis (D03)
      if (ctx.state == PoiState.outside && distance <= radius + approachMargin) {
        ctx.state = PoiState.approaching;
        if (!ctx.approachBuzzed) {
          ctx.approachBuzzed = true;
          // Event to buzz and show banner
          events.add(PoiApproached(poiId: poi.id, distanceM: distance)); 
        }
      } else if (ctx.state == PoiState.approaching && distance > radius + approachExitMargin) {
        ctx.state = PoiState.outside;
        ctx.approachBuzzed = false;
      }

      // Handle Trigger Debounce
      if (ctx.state == PoiState.outside || ctx.state == PoiState.approaching) {
        if (distance <= radius) {
          ctx.debounceCount++;
          if (ctx.debounceCount >= _content.park.param('debounce_readings')) {
            triggerCandidates.add(MapEntry(poi, distance));
          }
        } else {
          ctx.debounceCount = 0; // Reset debounce if a good fix is outside radius
        }
      }
      
      // Handle Cooldown Exit Logic (D04)
      if (ctx.state == PoiState.cooldown || ctx.state == PoiState.visited) {
         if (distance > radius + _content.park.param('retrigger_exit_margin_m')) {
           ctx.leftRetriggerZone = true;
         }
         
         if (ctx.state == PoiState.cooldown && ctx.leftRetriggerZone) {
            final cooldownMin = _content.park.param('cooldown_min');
            if (ctx.triggeredAt != null && 
                _clock.now().difference(ctx.triggeredAt!).inMinutes >= cooldownMin) {
              ctx.state = PoiState.outside;
              ctx.debounceCount = 0;
              ctx.leftRetriggerZone = false;
              ctx.approachBuzzed = false;
            }
         }
      }
    }

    // 2. Trigger the nearest candidate (D01)
    if (triggerCandidates.isNotEmpty) {
      triggerCandidates.sort((a, b) => a.value.compareTo(b.value));
      final nearest = triggerCandidates.first.key;
      final ctx = _poiContexts[nearest.id]!;
      
      ctx.state = PoiState.triggered;
      ctx.triggeredAt = _clock.now();
      ctx.leftRetriggerZone = false;
      
      events.add(PoiTriggered(
        at: ctx.triggeredAt!, 
        poiId: nearest.id, 
        source: TriggerSource.gps
      ));
    }

    return events;
  }

  void onQrScanned(String poiId) {
    if (_poiContexts.containsKey(poiId)) {
      final ctx = _poiContexts[poiId]!;
      ctx.state = PoiState.visited; // QR bypasses Triggered directly to Visited
      ctx.triggeredAt = _clock.now();
    }
  }

  void onManualPick(String poiId) {
    if (_poiContexts.containsKey(poiId)) {
      final ctx = _poiContexts[poiId]!;
      ctx.state = PoiState.visited;
      ctx.triggeredAt = _clock.now();
    }
  }
}