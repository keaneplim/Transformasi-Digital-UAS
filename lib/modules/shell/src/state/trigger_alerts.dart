import 'dart:async';

import 'package:jelajah_taman/core/core.dart';
import 'package:jelajah_taman/modules/notify/notify.dart';

import 'guide_controller.dart';

/// PB07: turns the guide's trigger state into alerts the visitor notices without looking.
///
/// One source of truth: [GuideController.pendingTrigger]. The system notification only mirrors
/// it, so answering in the app removes the notification and answering on the notification
/// removes the card.
/// - App visible: in-app card (already drawn by the overlay) + vibration. No system
///   notification, it would only cover the card.
/// - App hidden or screen locked (during a session): high-priority notification on the lock
///   screen with Dengarkan / Lihat detail / Nanti. A card still open when the phone is locked
///   is posted at that moment.
/// - Approaching (E3, once per approach): a quiet notification with sound + one short buzz, in
///   both states; Android always lets notifications vibrate, a background app often not.
/// - Taps come back here from the main isolate or forwarded from the plugin's background
///   engine, and go into the guide like the card's own buttons.
class TriggerAlerts {
  TriggerAlerts({
    required this.guide,
    required this.notifier,
    required EventBus bus,
    required this.navigate,
  }) {
    _wasActive = guide.sessionActive;
    guide.addListener(_onGuide);
    _subs
      ..add(bus.on<PoiApproached>().listen(_onApproached))
      ..add(notifier.taps.listen(handleTap));
    final launch = notifier.takeLaunchTap();
    // After the first frame's listeners exist (the guide may just have restored a session).
    if (launch != null) scheduleMicrotask(() => handleTap(launch));
  }

  final GuideController guide;
  final AlertNotifier notifier;

  /// Opens a route (`/poi/P05`); the app defers it while the splash is showing.
  final void Function(String path) navigate;

  final List<StreamSubscription<Object?>> _subs = [];
  bool _visible = true;
  bool _wasActive = false;

  /// Last pending trigger seen on the guide.
  String? _pending;

  /// POI whose trigger notification is currently posted.
  String? _posted;

  /// Two short pulses (IMPLEMENTATION_PLAN F04 "Vibration patterns").
  static const triggerVibration = [0, 200, 150, 200];

  /// The app is on screen (resumed, or only covered by the notification shade).
  void setVisible(bool visible) {
    if (visible == _visible) return;
    _visible = visible;
    if (!visible) _postPending();
  }

  void _onGuide() {
    final id = guide.pendingTrigger?.id;
    if (id != _pending) {
      _pending = id;
      if (_posted != null && _posted != id) _cancelTrigger();
      if (id != null) {
        unawaited(notifier.cancelApproach());
        if (_visible) {
          if (guide.vibration) unawaited(notifier.vibrate(triggerVibration));
        } else {
          _postPending();
        }
      }
    }
    if (_wasActive && !guide.sessionActive) {
      _cancelTrigger();
      unawaited(notifier.cancelApproach());
    }
    _wasActive = guide.sessionActive;
  }

  void _postPending() {
    final p = guide.pendingTrigger;
    if (p == null || !guide.sessionActive || _posted == p.id) return;
    _posted = p.id;
    unawaited(notifier.showTrigger(
      poiId: p.id,
      title: 'Anda tiba di ${p.name}',
      body: 'Ingin mendengar ceritanya?',
      listenLabel: 'Dengarkan',
    ));
  }

  void _cancelTrigger() {
    _posted = null;
    unawaited(notifier.cancelTrigger());
  }

  void _onApproached(PoiApproached e) {
    if (!guide.sessionActive || guide.pendingTrigger != null) return;
    final p = guide.place(e.poiId);
    if (p == null) return;
    // Same wording as the in-app banner; rounded so it doesn't read like a measurement.
    final metres = (e.distanceM / 5).round() * 5;
    unawaited(notifier.showApproach(
      poiId: p.id,
      title: 'Hampir sampai: ${p.name}',
      body: 'Sekitar $metres m lagi.',
    ));
  }

  /// A notification tap, already back in the main isolate.
  void handleTap(AlertTap tap) {
    final p = guide.place(tap.poiId);
    if (p == null || !p.isPoi) return;
    // A button removes its notification itself (cancelNotification).
    if (_posted == tap.poiId) _posted = null;
    final isPending = guide.pendingTrigger?.id == tap.poiId;
    switch (tap.action) {
      case AlertAction.listen:
        if (isPending) {
          guide.resolveTrigger(engaged: true, how: EngagementKind.listened);
        }
        // Plays without opening the app. Counts as a visit only if it triggered (D05).
        guide.playAudio(p);
      case AlertAction.detail:
        if (isPending) guide.resolveTrigger(engaged: true);
        navigate('/poi/${p.id}');
      case AlertAction.later:
        if (isPending) guide.resolveTrigger(engaged: false);
      case AlertAction.show:
        break; // the app opens on the trigger card, which is still pending
    }
  }

  void dispose() {
    guide.removeListener(_onGuide);
    for (final s in _subs) {
      unawaited(s.cancel());
    }
  }
}
