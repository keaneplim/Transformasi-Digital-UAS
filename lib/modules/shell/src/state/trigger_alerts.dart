import 'dart:async';

import 'package:jelajah_taman/core/core.dart';
import 'package:jelajah_taman/modules/notify/notify.dart';

import 'guide_controller.dart';
import 'places.dart';

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
/// - Reminders (A03 closing, F08 hydration; UI13): one buzz while the app is visible (the card
///   is on screen); a high-priority notification with Navigasi / Nanti (closing) or Navigasi /
///   Ingatkan 10 menit lagi (hydration) while it is hidden. Mirrors [GuideController.reminder]
///   like the trigger card: answered in the app → notification gone, and the other way round.
/// - Settings "Getar" also decides whether notifications vibrate (PB07).
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
    _recs = guide.recommendationCount;
    _vibration = guide.vibration;
    notifier.setVibration(_vibration);
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

  int _recs = 0;
  bool _nextPosted = false;
  bool _vibration = true;

  /// Last reminder seen on the guide, and whether its notification is posted.
  GuideReminder? _reminder;
  bool _reminderPosted = false;

  /// Two short pulses (IMPLEMENTATION_PLAN F04 "Vibration patterns").
  static const triggerVibration = [0, 200, 150, 200];

  /// One long pulse: a reminder appeared on screen.
  static const reminderVibration = [0, 400];

  /// The app is on screen (resumed, or only covered by the notification shade).
  void setVisible(bool visible) {
    if (visible == _visible) return;
    _visible = visible;
    if (!visible) {
      _postPending();
      _postReminder();
    }
    // Back on screen: the sheet itself shows the suggestion.
    if (visible) _cancelNext();
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
    if (guide.recommendationCount != _recs) {
      _recs = guide.recommendationCount;
      _postNext();
    }
    if (guide.reminder != _reminder) {
      _reminder = guide.reminder;
      _cancelReminder();
      if (_reminder != null) {
        if (!_visible) {
          _postReminder();
        } else if (guide.vibration) {
          unawaited(notifier.vibrate(reminderVibration));
        }
      }
    }
    if (guide.vibration != _vibration) {
      _vibration = guide.vibration;
      notifier.setVibration(_vibration);
    }
    if (_wasActive && !guide.sessionActive) {
      _cancelTrigger();
      _cancelNext();
      _cancelReminder();
      unawaited(notifier.cancelApproach());
    }
    _wasActive = guide.sessionActive;
  }

  /// UI13 on the lock screen, same words as the card and the voice.
  void _postReminder() {
    final r = guide.reminder;
    if (r == null || !guide.sessionActive || _reminderPosted) return;
    _reminderPosted = true;
    final to = guide.reminderDestination(r);
    final closing = r == GuideReminder.closing;
    unawaited(notifier.showReminder(
      kind: closing ? ReminderKind.closing : ReminderKind.hydration,
      destinationId: to.id,
      title: closing
          ? 'Kawasan tutup pukul ${clockLabel(guide.closingTime)}'
          : guide.hydrationLine,
      body: closing
          ? 'Jalan kaki ke gerbang sekitar ${minutesLabel(guide.walkToGate)} '
              'dari posisi Anda. Mulai kembali sekarang.'
          : 'Tempat istirahat terdekat: ${to.name}, '
              '${distanceLabel(guide.walkingM(to))}.',
      navigateLabel: closing ? 'Navigasi ke gerbang' : 'Ke tempat istirahat',
      laterLabel: closing ? 'Nanti' : 'Ingatkan 10 menit lagi',
      snoozes: !closing,
    ));
  }

  void _cancelReminder() {
    if (!_reminderPosted) return;
    _reminderPosted = false;
    unawaited(notifier.cancelReminder());
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

  /// F07 with the screen off: silent card for the next suggestion (the voice says it).
  void _postNext() {
    final last = guide.lastRecommendation;
    if (_visible || last == null || !guide.sessionActive) return;
    final rec = last.rec;
    final main = rec.items.isEmpty ? null : rec.items.first.place;
    _nextPosted = true;
    unawaited(main == null
        ? notifier.showNext(
            poiId: guide.gatePlace.id,
            title: rec.allVisited
                ? 'Semua tempat sudah Anda kunjungi'
                : 'Waktunya kembali ke gerbang',
            body: '${gateWalkLabel(rec.gateWalk)}.',
          )
        : notifier.showNext(
            poiId: main.id,
            title: 'Berikutnya: ${main.name}',
            body: '±${minutesLabel(guide.walkingTime(main))} jalan kaki. '
                'Buka untuk melihat pilihan lain.',
          ));
  }

  void _cancelNext() {
    if (!_nextPosted) return;
    _nextPosted = false;
    unawaited(notifier.cancelNext());
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
    if (tap.reminder != null) return _handleReminderTap(tap);
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
      case AlertAction.navigate || AlertAction.snooze:
        break; // reminder buttons only
    }
  }

  void _handleReminderTap(AlertTap tap) {
    // A button removes its notification itself (cancelNotification).
    _reminderPosted = false;
    final r = tap.reminder == ReminderKind.hydration
        ? GuideReminder.hydration
        : GuideReminder.closing;
    final open = guide.reminder == r;
    switch (tap.action) {
      case AlertAction.navigate:
        // Also for a reminder already answered: the visitor asked for the way.
        if (guide.navigateForReminder(r)) navigate('/navigate');
      case AlertAction.snooze:
        if (open) guide.snoozeReminder();
      case AlertAction.later:
        if (open) guide.dismissReminder();
      case AlertAction.show || AlertAction.listen || AlertAction.detail:
        break; // the app opens on the reminder card, which is still there
    }
  }

  void dispose() {
    guide.removeListener(_onGuide);
    for (final s in _subs) {
      unawaited(s.cancel());
    }
  }
}
