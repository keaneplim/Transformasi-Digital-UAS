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

/// The POI id travels as the notification payload; the button id says what was tapped.
AlertTap? tapOf(NotificationResponse r) {
  final poi = r.payload;
  if (poi == null || poi.isEmpty) return null;
  return AlertTap(poi, AlertTap.actionFor(r.actionId));
}

/// [AlertNotifier] on Android with flutter_local_notifications + vibration (owned by `notify`,
/// rule R5). Created once at startup by the composition root.
class LocalAlertNotifier implements AlertNotifier {
  LocalAlertNotifier._(this._plugin);

  final FlutterLocalNotificationsPlugin _plugin;
  final StreamController<AlertTap> _taps = StreamController.broadcast();
  final ReceivePort _port = ReceivePort();
  AlertTap? _launchTap;

  static const triggerId = 7001;
  static const approachId = 7002;
  static const _icon = 'ic_stat_jelajah';

  /// Channel settings are fixed once created on the phone (Android 8+): changing them needs a
  /// new channel id.
  static final _triggerChannel = AndroidNotificationChannel(
    'trigger',
    'Tiba di tempat menarik',
    description: 'Saat Anda tiba di tempat menarik selama penjelajahan',
    importance: Importance.high,
    vibrationPattern: Int64List.fromList(const [0, 200, 150, 200]),
  );

  static final _approachChannel = AndroidNotificationChannel(
    'approach',
    'Mendekati tempat menarik',
    description: 'Getar dan bunyi singkat saat Anda mendekati tempat menarik',
    vibrationPattern: Int64List.fromList(const [0, 300]),
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
    await android?.createNotificationChannel(_triggerChannel);
    await android?.createNotificationChannel(_approachChannel);

    final launch = await plugin.getNotificationAppLaunchDetails();
    final response = launch?.notificationResponse;
    if ((launch?.didNotificationLaunchApp ?? false) && response != null) {
      n._launchTap = tapOf(response);
    }
    // Leftovers from a run the OS killed. Only our own ids: cancelAll() would also try to
    // remove the GPS foreground-service notification.
    await plugin.cancel(id: triggerId);
    await plugin.cancel(id: approachId);
    return n;
  }

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
          {required String poiId,
          required String title,
          required String body}) =>
      _show(
        id: approachId,
        poiId: poiId,
        title: title,
        body: body,
        details: AndroidNotificationDetails(
          _approachChannel.id,
          _approachChannel.name,
          channelDescription: _approachChannel.description,
          icon: _icon,
          vibrationPattern: _approachChannel.vibrationPattern,
          category: AndroidNotificationCategory.navigation,
          visibility: NotificationVisibility.public,
          onlyAlertOnce: true,
          timeoutAfter: const Duration(minutes: 2).inMilliseconds,
        ),
      );

  @override
  Future<void> cancelApproach() => _cancel(approachId);

  @override
  Future<void> showTrigger({
    required String poiId,
    required String title,
    required String body,
    required String listenLabel,
  }) =>
      _show(
        id: triggerId,
        poiId: poiId,
        title: title,
        body: body,
        details: AndroidNotificationDetails(
          _triggerChannel.id,
          _triggerChannel.name,
          channelDescription: _triggerChannel.description,
          icon: _icon,
          importance: Importance.high,
          priority: Priority.high,
          vibrationPattern: _triggerChannel.vibrationPattern,
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

  @override
  Future<void> cancelTrigger() => _cancel(triggerId);

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
    required String poiId,
    required String title,
    required String body,
    required AndroidNotificationDetails details,
  }) async {
    try {
      await _plugin.show(
        id: id,
        title: title,
        body: body,
        payload: poiId,
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
