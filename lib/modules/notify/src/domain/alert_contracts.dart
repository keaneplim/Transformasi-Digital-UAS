/// What the visitor did with a trigger notification (UI05, PB07).
enum AlertAction {
  /// "Dengarkan": play the narration without opening the app.
  listen,

  /// "Lihat detail": open the app on the POI detail page.
  detail,

  /// "Nanti": dismiss; the POI stays triggered, not visited (D05).
  later,

  /// Tap on the notification body: open the app (the trigger card is still there).
  show,
}

/// One tap on a notification, as delivered to the main isolate.
class AlertTap {
  const AlertTap(this.poiId, this.action);

  final String poiId;
  final AlertAction action;

  /// Button id → action. A tap on the body has no button id.
  static AlertAction actionFor(String? buttonId) =>
      AlertAction.values.asNameMap()[buttonId] ?? AlertAction.show;

  /// Message format between the background notification engine and the main isolate.
  /// Only strings: a `SendPort` can carry them between isolates of different engines.
  Map<String, String> toMessage() => {'poi': poiId, 'action': action.name};

  /// Null for anything that isn't a well-formed message (never trust a port blindly).
  static AlertTap? fromMessage(Object? message) {
    if (message is! Map) return null;
    final poi = message['poi'];
    final action = AlertAction.values.asNameMap()[message['action']];
    if (poi is! String || poi.isEmpty || action == null) return null;
    return AlertTap(poi, action);
  }

  @override
  bool operator ==(Object other) =>
      other is AlertTap && other.poiId == poiId && other.action == action;

  @override
  int get hashCode => Object.hash(poiId, action);

  @override
  String toString() => 'AlertTap($poiId, ${action.name})';
}

/// System notifications and vibration (module `notify`, ARCHITECTURE §3). The plugin adapter
/// lives in `src/data/`; tests use a fake. Copy is passed in, so the wording stays with the
/// screens that own it.
abstract interface class AlertNotifier {
  /// Android 13+ runtime permission. True when notifications may be shown.
  Future<bool> requestPermission();

  /// UI04 when the phone isn't being looked at: sound + one short vibration, no pop-up.
  Future<void> showApproach(
      {required String poiId, required String title, required String body});

  Future<void> cancelApproach();

  /// UI05 on the lock screen: high priority, with Dengarkan / Lihat detail / Nanti.
  Future<void> showTrigger({
    required String poiId,
    required String title,
    required String body,
    required String listenLabel,
  });

  Future<void> cancelTrigger();

  /// In-app vibration while the app is visible (milliseconds: wait, buzz, wait, buzz…).
  Future<void> vibrate(List<int> pattern);

  /// Taps on notifications, from the main isolate and forwarded from the background engine.
  Stream<AlertTap> get taps;

  /// The tap that cold-started the app, if any. Returned once.
  AlertTap? takeLaunchTap();
}
