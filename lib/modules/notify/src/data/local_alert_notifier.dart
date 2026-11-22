import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';
import 'dart:ui' show IsolateNameServer;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:jelajah_taman/core/core.dart';
import 'package:vibration/vibration.dart';

import '../domain/alert_contracts.dart';

/// Name under which the main isolate listens for taps forwarded from the background engine.
const notifyTapPortName = 'jelajah_taman.notify.taps';

/// Runs in the **separate Flutter engine** that flutter_local_notifications starts for buttons
/// that don't open the app (Dengarkan, Nanti) — also while the app is running (its
/// `ActionBroadcastReceiver` always calls `startEngine`). That engine has no app state, audio
/// player or session, so this only forwards the tap to the main isolate (ARCHITECTURE §5.3,
/// T12 spike option b). Process-wide `IsolateNameServer` connects the two engines.
@pragma('vm:entry-point')
void forwardNotificationTapToMainIsolate(NotificationResponse response) {
  final tap = tapOf(response);
  if (tap == null) return;
  // Null when the OS killed the app's main isolate: nothing can play then. The notification
  // expires by itself (timeoutAfter) and is cleared on the next launch.
  IsolateNameServer.lookupPortByName(notifyTapPortName)?.send(tap.toMessage());
}

/// The POI id (or `reminder|kind|destination`) travels as the notification payload; the
/// button id says what was tapped.
AlertTap? tapOf(NotificationResponse r) =>
    AlertTap.fromPayload(r.payload, r.actionId);

/// [AlertNotifier] on Android with flutter_local_notifications + vibration (owned by `notify`,
/// rule R5). Created once at startup by the composition root.
class LocalAlertNotifier implements AlertNotifier {
  LocalAlertNotifier._(this._plugin);

  final FlutterLocalNotificationsPlugin _plugin;
  final StreamController<AlertTap> _taps = StreamController.broadcast();
  final ReceivePort _port = ReceivePort();
  AlertTap? _launchTap;
  bool _vibrate = true;

  static const triggerId = 7001;
  static const approachId = 7002;
  static const nextId = 7003;
  static const reminderId = 7004;
  static const _icon = 'ic_stat_jelajah';

  /// Channel settings are fixed once created on the phone (Android 8+): changing them needs a
  /// new channel id. So every channel that vibrates has a quiet twin, used while Settings →
  /// "Getar" is off (PB07); the visitor sees both in the phone's notification settings.
  static final _triggerChannel = _ChannelPair(
    'trigger',
    'Tiba di tempat menarik',
    'Saat Anda tiba di tempat menarik selama penjelajahan',
    importance: Importance.high,
    vibration: const [0, 200, 150, 200],
  );

  static final _approachChannel = _ChannelPair(
    'approach',
    'Mendekati tempat menarik',
    'Bunyi singkat saat Anda mendekati tempat menarik',
    importance: Importance.defaultImportance,
    vibration: const [0, 300],
  );

  /// A03 closing time, F08 hydration (IMPLEMENTATION_PLAN §6.2 `reminder`).
  static final _reminderChannel = _ChannelPair(
    'reminder',
    'Pengingat',
    'Pengingat jam tutup kawasan dan waktu minum air',
    importance: Importance.high,
    vibration: const [0, 400, 200, 400],
  );

  /// UC-A03-2 final call: stronger 3-pulse vibration on the lock screen (with quiet twin).
  static final _finalCallChannel = _ChannelPair(
    'final_call',
    'Panggilan terakhir',
    'Peringatan mendesak saat waktu tempuh ke gerbang mendekati jam tutup',
    importance: Importance.high,
    vibration: const [0, 400, 150, 400, 150, 400],
  );

  static const _nextChannel = AndroidNotificationChannel(
    'next',
    'Rekomendasi berikutnya',
    description: 'Tempat yang disarankan setelah Anda selesai di sebuah tempat',
    importance: Importance.low,
    playSound: false,
    enableVibration: false,
  );

  static Future<LocalAlertNotifier> create() async {
    final n = LocalAlertNotifier._(FlutterLocalNotificationsPlugin());
    try {
      return await n._init();
    } on Object {
      await n
          .dispose(); // don't leave the port open when the plugin isn't there
      rethrow;
    }
  }

  Future<LocalAlertNotifier> _init() async {
    final plugin = _plugin;
    final n = this;
    // Re-register: a hot restart or a previous engine may have left a stale port behind.
    IsolateNameServer.removePortNameMapping(notifyTapPortName);
    IsolateNameServer.registerPortWithName(n._port.sendPort, notifyTapPortName);
    n._port.listen((message) {
      final tap = AlertTap.fromMessage(message);
      if (tap != null) n._taps.add(tap);
    });

    await plugin.initialize(
      settings: const InitializationSettings(
          android: AndroidInitializationSettings(_icon)),
      onDidReceiveNotificationResponse: (r) {
        final tap = tapOf(r);
        if (tap != null) n._taps.add(tap);
      },
      onDidReceiveBackgroundNotificationResponse:
          forwardNotificationTapToMainIsolate,
    );
    final android = plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    for (final c in [
      ..._triggerChannel.both,
      ..._approachChannel.both,
      ..._reminderChannel.both,
      ..._finalCallChannel.both,
      _nextChannel,
    ]) {
      await android?.createNotificationChannel(c);
    }

    final launch = await plugin.getNotificationAppLaunchDetails();
    final response = launch?.notificationResponse;
    if ((launch?.didNotificationLaunchApp ?? false) && response != null) {
      n._launchTap = tapOf(response);
    }
    // Leftovers from a run the OS killed. Only our own ids: cancelAll() would also try to
    // remove the GPS foreground-service notification.
    await plugin.cancel(id: triggerId);
    await plugin.cancel(id: approachId);
    await plugin.cancel(id: nextId);
    await plugin.cancel(id: reminderId);
    return n;
  }

  @override
  void setVibration(bool on) => _vibrate = on;

  @override
  Future<bool> requestPermission() async {
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      return await android?.requestNotificationsPermission() ?? true;
    } on Object catch (e) {
      AppLog.info('Notification permission request failed: $e');
      return false;
    }
  }

  @override
  Future<void> showApproach(
      {required String poiId, required String title, required String body}) {
    final channel = _approachChannel.pick(vibrate: _vibrate);
    return _show(
      id: approachId,
      payload: poiId,
      title: title,
      body: body,
      details: AndroidNotificationDetails(
        channel.id,
        channel.name,
        channelDescription: channel.description,
        icon: _icon,
        enableVibration: channel.enableVibration,
        vibrationPattern: channel.vibrationPattern,
        category: AndroidNotificationCategory.navigation,
        visibility: NotificationVisibility.public,
        onlyAlertOnce: true,
        timeoutAfter: const Duration(minutes: 2).inMilliseconds,
      ),
    );
  }

  @override
  Future<void> cancelApproach() => _cancel(approachId);

  @override
  Future<void> showTrigger({
    required String poiId,
    required String title,
    required String body,
    required String listenLabel,
  }) {
    final channel = _triggerChannel.pick(vibrate: _vibrate);
    return _show(
      id: triggerId,
      payload: poiId,
      title: title,
      body: body,
      details: AndroidNotificationDetails(
        channel.id,
        channel.name,
        channelDescription: channel.description,
        icon: _icon,
        importance: Importance.high,
        priority: Priority.high,
        enableVibration: channel.enableVibration,
        vibrationPattern: channel.vibrationPattern,
        category: AndroidNotificationCategory.recommendation,
        // Shown in full on the lock screen: a place name is not private.
        visibility: NotificationVisibility.public,
        // Buttons only work while the app runs; don't leave a dead card for hours.
        timeoutAfter: const Duration(minutes: 10).inMilliseconds,
        actions: [
          // Runs in the background engine → forwarded; works without unlocking.
          AndroidNotificationAction(AlertAction.listen.name, listenLabel),
          AndroidNotificationAction(AlertAction.detail.name, 'Lihat detail',
              showsUserInterface: true),
          AndroidNotificationAction(AlertAction.later.name, 'Nanti'),
        ],
      ),
    );
  }

  @override
  Future<void> cancelTrigger() => _cancel(triggerId);

  @override
  Future<void> showNext(
          {required String poiId,
          required String title,
          required String body}) =>
      _show(
        id: nextId,
        payload: poiId,
        title: title,
        body: body,
        details: AndroidNotificationDetails(
          _nextChannel.id,
          _nextChannel.name,
          channelDescription: _nextChannel.description,
          icon: _icon,
          importance: Importance.low,
          priority: Priority.low,
          playSound: false,
          enableVibration: false,
          category: AndroidNotificationCategory.recommendation,
          visibility: NotificationVisibility.public,
          onlyAlertOnce: true,
          timeoutAfter: const Duration(minutes: 10).inMilliseconds,
        ),
      );

  @override
  Future<void> cancelNext() => _cancel(nextId);

  @override
  Future<void> showReminder({
    required ReminderKind kind,
    required String destinationId,
    required String title,
    required String body,
    required String navigateLabel,
    required String laterLabel,
    required bool snoozes,
  }) {
    final pair =
        kind == ReminderKind.finalCall ? _finalCallChannel : _reminderChannel;
    final channel = pair.pick(vibrate: _vibrate);
    assert(channel.id == reminderChannelId(kind, vibrate: _vibrate));
    return _show(
      id: reminderId,
      payload: AlertTap.payloadOf(poiId: destinationId, reminder: kind),
      title: title,
      body: body,
      details: AndroidNotificationDetails(
        channel.id,
        channel.name,
        channelDescription: channel.description,
        icon: _icon,
        importance: Importance.high,
        priority: Priority.high,
        enableVibration: channel.enableVibration,
        vibrationPattern: channel.vibrationPattern,
        category: AndroidNotificationCategory.reminder,
        visibility: NotificationVisibility.public,
        styleInformation: BigTextStyleInformation(body),
        // Buttons only work while the app runs (as for the trigger card).
        timeoutAfter: const Duration(minutes: 30).inMilliseconds,
        actions: [
          AndroidNotificationAction(AlertAction.navigate.name, navigateLabel,
              showsUserInterface: true),
          // Background engine → forwarded; works without unlocking.
          AndroidNotificationAction(
              (snoozes ? AlertAction.snooze : AlertAction.later).name,
              laterLabel),
        ],
      ),
    );
  }

  @override
  Future<void> cancelReminder() => _cancel(reminderId);

  @override
  Future<void> vibrate(List<int> pattern) async {
    try {
      if (await Vibration.hasVibrator()) {
        await Vibration.vibrate(pattern: pattern);
      }
    } on Object catch (e) {
      AppLog.info('Vibration failed: $e');
    }
  }

  @override
  Stream<AlertTap> get taps => _taps.stream;

  @override
  AlertTap? takeLaunchTap() {
    final tap = _launchTap;
    _launchTap = null;
    return tap;
  }

  Future<void> _show({
    required int id,
    required String payload,
    required String title,
    required String body,
    required AndroidNotificationDetails details,
  }) async {
    try {
      await _plugin.show(
        id: id,
        title: title,
        body: body,
        payload: payload,
        notificationDetails: NotificationDetails(android: details),
      );
    } on Object catch (e) {
      // e.g. permission denied: the in-app card still works.
      AppLog.info('Notification $id not shown: $e');
    }
  }

  Future<void> _cancel(int id) async {
    try {
      await _plugin.cancel(id: id);
    } on Object catch (e) {
      AppLog.info('Notification $id not cancelled: $e');
    }
  }

  Future<void> dispose() async {
    IsolateNameServer.removePortNameMapping(notifyTapPortName);
    _port.close();
    await _taps.close();
  }
}

/// A channel and its quiet twin (same name + "(tanpa getar)", no vibration).
class _ChannelPair {
  _ChannelPair(String id, String name, String description,
      {required Importance importance, required List<int> vibration})
      : loud = AndroidNotificationChannel(
          id,
          name,
          description: description,
          importance: importance,
          vibrationPattern: Int64List.fromList(vibration),
        ),
        quiet = AndroidNotificationChannel(
          '${id}_quiet',
          '$name (tanpa getar)',
          description: description,
          importance: importance,
          enableVibration: false,
        );

  final AndroidNotificationChannel loud;
  final AndroidNotificationChannel quiet;

  List<AndroidNotificationChannel> get both => [loud, quiet];

  AndroidNotificationChannel pick({required bool vibrate}) =>
      vibrate ? loud : quiet;
}
