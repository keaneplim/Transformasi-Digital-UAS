import 'package:flutter_test/flutter_test.dart';
import 'package:jelajah_taman/core/core.dart';
import 'package:jelajah_taman/modules/notify/notify.dart';

void main() {
  test('button id → action; a tap on the body opens the app', () {
    expect(AlertTap.actionFor('listen'), AlertAction.listen);
    expect(AlertTap.actionFor('detail'), AlertAction.detail);
    expect(AlertTap.actionFor('later'), AlertAction.later);
    expect(AlertTap.actionFor(null), AlertAction.show);
    expect(AlertTap.actionFor('something-else'), AlertAction.show);
  });

  test('message between the background engine and the main isolate round-trips',
      () {
    for (final action in AlertAction.values) {
      final tap = AlertTap('P05', action);
      expect(AlertTap.fromMessage(tap.toMessage()), tap);
      final reminder = AlertTap('P01', action, reminder: ReminderKind.closing);
      expect(AlertTap.fromMessage(reminder.toMessage()), reminder);
    }
  });

  test('malformed port messages are dropped, not trusted', () {
    expect(AlertTap.fromMessage(null), isNull);
    expect(AlertTap.fromMessage('P05'), isNull);
    expect(AlertTap.fromMessage({'poi': 'P05'}), isNull);
    expect(AlertTap.fromMessage({'poi': '', 'action': 'listen'}), isNull);
    expect(AlertTap.fromMessage({'poi': 'P05', 'action': 'explode'}), isNull);
    expect(AlertTap.fromMessage({'poi': 5, 'action': 'listen'}), isNull);
  });

  test('payload: a POI id, or reminder|kind|destination', () {
    expect(AlertTap.payloadOf(poiId: 'P05'), 'P05');
    final p =
        AlertTap.payloadOf(poiId: 'FS07', reminder: ReminderKind.hydration);
    expect(p, 'reminder|hydration|FS07');
    expect(
        AlertTap.fromPayload(p, 'snooze'),
        const AlertTap('FS07', AlertAction.snooze,
            reminder: ReminderKind.hydration));
    expect(AlertTap.fromPayload('P05', null),
        const AlertTap('P05', AlertAction.show));
  });

  test('malformed payloads are dropped', () {
    expect(AlertTap.fromPayload(null, null), isNull);
    expect(AlertTap.fromPayload('', 'listen'), isNull);
    expect(AlertTap.fromPayload('reminder|nap|P01', null), isNull);
    expect(AlertTap.fromPayload('reminder|closing|', null), isNull);
    expect(AlertTap.fromPayload('x|closing|P01', null), isNull);
    expect(
        AlertTap.fromMessage(
            {'poi': 'P01', 'action': 'later', 'reminder': 'nap'}),
        isNull);
  });

  test('reminderChannelId selects dedicated final_call channel and quiet twins',
      () {
    expect(reminderChannelId(ReminderKind.closing, vibrate: true), 'reminder');
    expect(reminderChannelId(ReminderKind.closing, vibrate: false),
        'reminder_quiet');
    expect(
        reminderChannelId(ReminderKind.hydration, vibrate: true), 'reminder');
    expect(
        reminderChannelId(ReminderKind.finalCall, vibrate: true), 'final_call');
    expect(reminderChannelId(ReminderKind.finalCall, vibrate: false),
        'final_call_quiet');
  });
}
