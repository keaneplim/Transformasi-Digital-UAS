enum PoiState { outside, approaching, triggered, visited, cooldown }

/// Trigger sources use `TriggerSource` from core/events (gps, qr, manual).
abstract interface class TriggerEngine {
  Map<String, PoiState> get states;

  /// Jumps straight to Triggered + Visited (PRD §4.2).
  void onQrScanned(String poiId);

  void onManualPick(String poiId);
}
