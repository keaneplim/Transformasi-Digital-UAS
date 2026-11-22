import 'package:jelajah_taman/core/core.dart';

/// What the visitor did with a notification (UI05 trigger, UI13 reminder; PB07).
enum AlertAction {
  /// "Dengarkan": play the narration without opening the app.
  listen,

  /// "Lihat detail": open the app on the POI detail page.
  detail,

  /// "Nanti": dismiss. A trigger stays triggered, not visited (D05); a reminder counts as
  /// handled.
  later,

  /// Tap on the notification body: open the app (the card is still there).
  show,

  /// Reminder "Navigasi ke gerbang" / "Ke tempat istirahat": open the app navigating there.
  navigate,

  /// Hydration "Ingatkan 10 menit lagi" (#33): back in 10 minutes, without opening the app.
  snooze,
}

/// One tap on a notification, as delivered to the main isolate. [poiId] is the POI of a
/// trigger, or the destination of a reminder ([reminder] set).
class AlertTap {
  const AlertTap(this.poiId, this.action, {this.reminder});

  final String poiId;
  final AlertAction action;

  /// Set for a reminder notification (A03 closing, F08 hydration).
  final ReminderKind? reminder;

  /// Button id → action. A tap on the body has no button id.
  static AlertAction actionFor(String? buttonId) =>
      AlertAction.values.asNameMap()[buttonId] ?? AlertAction.show;

  /// What a notification carries as its payload: the POI id (`P05`), or
  /// `reminder|<kind>|<destination>` for a reminder.
  static String payloadOf({required String poiId, ReminderKind? reminder}) =>
      reminder == null ? poiId : 'reminder|${reminder.name}|$poiId';

  /// Reads a payload written by [payloadOf]; null for anything malformed.
  static AlertTap? fromPayload(String? payload, String? buttonId) {
    if (payload == null || payload.isEmpty) return null;
    final action = actionFor(buttonId);
    final parts = payload.split('|');
    if (parts.length == 1) return AlertTap(payload, action);
    if (parts.length != 3 || parts[0] != 'reminder' || parts[2].isEmpty) {
      return null;
    }
    final kind = ReminderKind.values.asNameMap()[parts[1]];
    if (kind == null) return null;
    return AlertTap(parts[2], action, reminder: kind);
  }

  /// Message format between the background notification engine and the main isolate.
  /// Only strings: a `SendPort` can carry them between isolates of different engines.
  Map<String, String> toMessage() => {
        'poi': poiId,
        'action': action.name,
        if (reminder != null) 'reminder': reminder!.name,
      };

  /// Null for anything that isn't a well-formed message (never trust a port blindly).
  static AlertTap? fromMessage(Object? message) {
    if (message is! Map) return null;
    final poi = message['poi'];
    final action = AlertAction.values.asNameMap()[message['action']];
    if (poi is! String || poi.isEmpty || action == null) return null;
    final rawKind = message['reminder'];
    if (rawKind == null) return AlertTap(poi, action);
    final kind = ReminderKind.values.asNameMap()[rawKind];
    if (kind == null) return null;
    return AlertTap(poi, action, reminder: kind);
  }

  @override
  bool operator ==(Object other) =>
      other is AlertTap &&
      other.poiId == poiId &&
      other.action == action &&
      other.reminder == reminder;

  @override
  int get hashCode => Object.hash(poiId, action, reminder);

  @override
  String toString() =>
      'AlertTap($poiId, ${action.name}${reminder == null ? '' : ', ${reminder!.name}'})';
}

/// System notifications and vibration (module `notify`, ARCHITECTURE §3). The plugin adapter
/// lives in `src/data/`; tests use a fake. Copy is passed in, so the wording stays with the
/// screens that own it.
abstract interface class AlertNotifier {
  /// Android 13+ runtime permission. True when notifications may be shown.
  Future<bool> requestPermission();

  /// Settings "Getar" (PB07): whether notifications vibrate. Android fixes a channel's
  /// vibration when it is created, so the adapter switches between a vibrating and a quiet
  /// copy of each channel.
  void setVibration(bool on);

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

  /// F07 when the phone isn't being looked at: the next suggestion, silent (no sound, no
  /// vibration; the voice line already said it). A tap opens the app on the sheet.
  Future<void> showNext(
      {required String poiId, required String title, required String body});

  Future<void> cancelNext();

  /// UI13 when the phone isn't being looked at (A03 closing, F08 hydration): high priority,
  /// sound, with [navigateLabel] (opens the app navigating to [destinationId]) and
  /// [laterLabel] ("Nanti", or "Ingatkan 10 menit lagi" when [snoozes]).
  Future<void> showReminder({
    required ReminderKind kind,
    required String destinationId,
    required String title,
    required String body,
    required String navigateLabel,
    required String laterLabel,
    required bool snoozes,
  });

  Future<void> cancelReminder();

  /// In-app vibration while the app is visible (milliseconds: wait, buzz, wait, buzz…).
  Future<void> vibrate(List<int> pattern);

  /// Taps on notifications, from the main isolate and forwarded from the background engine.
  Stream<AlertTap> get taps;

  /// The tap that cold-started the app, if any. Returned once.
  AlertTap? takeLaunchTap();
}
