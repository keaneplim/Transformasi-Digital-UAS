abstract interface class SessionLog {
  Set<String> get triggeredPoiIds;

  /// Only POIs the visitor engaged with (decision D05). "Nanti" doesn't count.
  Set<String> get visitedPoiIds;

  String? get lastVisitedPoiId;

  Stream<void> get changes;
}
