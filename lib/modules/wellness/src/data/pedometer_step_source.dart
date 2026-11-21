import 'package:pedometer/pedometer.dart';

import '../domain/steps.dart';

/// [StepSource] on the pedometer plugin: Android's TYPE_STEP_COUNTER (hardware, counts since
/// boot, keeps counting with the screen off). The plugin's stream errors with "StepCount not
/// available" on a phone without the sensor.
class PedometerStepSource implements StepSource {
  const PedometerStepSource();

  @override
  Stream<int> cumulativeSteps() =>
      Pedometer.stepCountStream.map((e) => e.steps);
}
