import 'package:flutter_test/flutter_test.dart';
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
}
