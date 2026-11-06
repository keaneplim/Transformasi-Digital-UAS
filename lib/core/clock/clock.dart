/// Source of "now" for the whole app (ARCHITECTURE.md rule R7).
///
/// Never call `DateTime.now()` anywhere else — `tools/check_architecture.dart` rejects it.
/// Tests and the debug menu use [FakeClock] (e.g. TC-10: simulate 15.30).
abstract interface class Clock {
  DateTime now();
}

class SystemClock implements Clock {
  const SystemClock();

  @override
  DateTime now() => DateTime.now(); // The only allowed DateTime.now() in lib/.
}

class FakeClock implements Clock {
  FakeClock(this._now);

  DateTime _now;

  @override
  DateTime now() => _now;

  void setNow(DateTime value) => _now = value;

  void advance(Duration duration) => _now = _now.add(duration);
}
