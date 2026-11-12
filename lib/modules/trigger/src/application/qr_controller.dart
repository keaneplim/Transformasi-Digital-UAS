import 'package:jelajah_taman/core/core.dart';
import 'package:jelajah_taman/modules/content/content.dart';
import 'package:jelajah_taman/modules/trigger/src/domain/trigger_engine.dart';

class QrController {
  final ContentRepository _content;
  final TriggerEngine _engine;
  final EventBus _eventBus;

  QrController(this._content, this._engine, this._eventBus);

  /// Parses the payload, triggers the engine, and returns the PoiId if successful.
  /// Returns null if the payload is invalid, foreign, or unknown (UC-A02-2).
  String? handleQrScan(String rawPayload) {
    final payload = rawPayload.trim().toLowerCase();
    
    // Validate scheme
    if (!payload.startsWith('jelajahtaman://poi/')) {
      return null;
    }

    // Extract ID (e.g., 'p05' -> 'P05')
    final idSegment = payload.split('/').last.toUpperCase();
    
    // Validate against content (Offline resolution)
    final poi = _content.poiById(idSegment);
    if (poi == null) {
      return null;
    }

    // Process through engine (Jumps to Triggered/Visited immediately)
    _engine.onQrScanned(poi.id);
    
    // Publish events for analytics and UI routing
    final now = Clock.now();
    _eventBus.publish(PoiTriggered(at: now, poiId: poi.id, source: TriggerSource.qr));
    _eventBus.publish(PoiVisited(at: now, poiId: poi.id));

    return poi.id;
  }
  
  void handleManualPick(String poiId) {
    _engine.onManualPick(poiId);
    final now = Clock.now();
    _eventBus.publish(PoiTriggered(at: now, poiId: poiId, source: TriggerSource.manual));
    _eventBus.publish(PoiVisited(at: now, poiId: poiId));
  }
}