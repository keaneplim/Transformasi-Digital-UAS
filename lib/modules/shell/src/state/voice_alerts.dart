import 'dart:async';

import 'package:jelajah_taman/core/core.dart';
import 'package:jelajah_taman/modules/audio/audio.dart';
import 'package:jelajah_taman/modules/routing/routing.dart';

import 'guide_controller.dart';
import 'places.dart';

/// F04: what the guide says out loud, so the park can be explored with the phone in a pocket.
///
/// Mirrors [TriggerAlerts]: it watches the guide and the bus and owns the spoken copy. The
/// [TtsService] (VoiceArbiter) decides what is said when; this class only decides what to say.
/// - Trigger prompt (always, F04 b): "Anda tiba di …. Ingin mendengar ceritanya?"; with
///   Auto-Play the short form, and the guide starts the narration when it has been said.
/// - Navigation (setting "Arahan suara", F04 e): start, each turn ~20 m ahead, re-route, arrival.
/// - Reminders (always, F04 f): closing time as a safety line, hydration as a reminder.
/// - Narration played to the end: "Selesai. Berikutnya: …" (UC-F04-1 step 5).
/// Silent outside a session. Narration ducks under every line (guide.onVoiceDuck).
class VoiceAlerts {
  VoiceAlerts({required this.guide, required this.tts, required EventBus bus}) {
    guide.announceTrigger = _announce;
    guide.addListener(_onGuide);
    _subs
      ..add(bus.on<ReminderDue>().listen(_onReminder))
      ..add(tts.duck.listen(guide.onVoiceDuck));
    // A restored session doesn't announce the route it was already on.
    _route = guide.navigation?.route;
    _to = guide.navigation?.to;
    _arrived = guide.arrivedAt != null;
    _reroutes = guide.reroutes;
    _done = guide.narrationsDone;
    _wasActive = guide.sessionActive;
    _skipPassedTurns();
  }

  final GuideController guide;
  final TtsService tts;

  /// A turn instruction is spoken this far before the turn (IMPLEMENTATION_PLAN F06 step 5).
  static const turnAheadM = 20.0;

  final List<StreamSubscription<Object?>> _subs = [];
  RouteResult? _route;
  Place? _to;
  final Set<int> _spokenTurns = {};
  bool _arrived = false;
  int _reroutes = 0;
  int _done = 0;
  bool _wasActive = false;

  bool get _navVoice => guide.sessionActive && guide.voiceGuidance;

  void _say(String text, VoicePriority priority) =>
      unawaited(tts.say(text, priority: priority));

  Future<void> _announce(Place p) {
    if (!guide.sessionActive) return Future.value();
    return tts.say(
      guide.autoPlay
          ? 'Anda tiba di ${p.name}.'
          : 'Anda tiba di ${p.name}. Ingin mendengar ceritanya?',
      priority: VoicePriority.triggerPrompt,
    );
  }

  void _onGuide() {
    if (_wasActive && !guide.sessionActive) unawaited(tts.stopAll());
    _wasActive = guide.sessionActive;
    _navigation();
    if (guide.narrationsDone != _done) {
      _done = guide.narrationsDone;
      _narrationDone();
    }
  }

  void _navigation() {
    final n = guide.navigation;
    if (!identical(n?.route, _route)) {
      final rerouted = n != null &&
          _route != null &&
          identical(n.to, _to) &&
          guide.reroutes != _reroutes;
      _route = n?.route;
      _to = n?.to;
      _spokenTurns.clear();
      _arrived = false;
      if (n != null && _navVoice) {
        if (rerouted) {
          _say('Rute diperbarui.', VoicePriority.navigation);
        } else {
          final min = (n.route.eta.inSeconds / 60).ceil().clamp(1, 999);
          _say('Menuju ${n.to.name}, sekitar $min menit.',
              VoicePriority.navigation);
        }
      }
    }
    _reroutes = guide.reroutes;
    if (n == null) return;

    final arrived = guide.arrivedAt != null;
    // A POI that triggers on arrival already says "Anda tiba di …" in its prompt.
    if (arrived &&
        !_arrived &&
        _navVoice &&
        guide.pendingTrigger?.id != n.to.id) {
      _say('Anda tiba di ${n.to.name}.', VoicePriority.navigation);
    }
    _arrived = arrived;
    if (arrived) return;

    final turns = n.route.turns;
    for (var i = 0; i < turns.length; i++) {
      final t = turns[i];
      if (t.direction == TurnDirection.arrive || _spokenTurns.contains(i)) {
        continue; // arrival is announced from arrivedAt (≤ 15 m), not from the route end
      }
      final ahead = t.distanceFromStartM - guide.navProgressM;
      if (ahead > turnAheadM) break; // turns are in route order
      _spokenTurns.add(i);
      // Already behind the visitor (fast demo walk): skip rather than give an old direction.
      if (ahead >= -5 && _navVoice) _say(t.text, VoicePriority.navigation);
    }
  }

  void _skipPassedTurns() {
    final n = guide.navigation;
    if (n == null) return;
    for (var i = 0; i < n.route.turns.length; i++) {
      if (n.route.turns[i].distanceFromStartM - guide.navProgressM <=
          turnAheadM) {
        _spokenTurns.add(i);
      }
    }
  }

  void _narrationDone() {
    if (!guide.sessionActive) return;
    final r = guide.recommend();
    // Back to the gate: the closing reminder / summary say what to do then.
    if (r.backToGate) return;
    _say('Selesai. Berikutnya: ${r.items.first.place.name}.',
        VoicePriority.reminder);
  }

  void _onReminder(ReminderDue e) {
    if (!guide.sessionActive) return;
    _say(
      e.text,
      e.kind == ReminderKind.hydration
          ? VoicePriority.reminder
          : VoicePriority.safety,
    );
  }

  void dispose() {
    if (guide.announceTrigger == _announce) guide.announceTrigger = null;
    guide.removeListener(_onGuide);
    for (final s in _subs) {
      unawaited(s.cancel());
    }
  }
}
