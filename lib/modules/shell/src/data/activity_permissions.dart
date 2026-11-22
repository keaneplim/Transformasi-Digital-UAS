import 'package:jelajah_taman/modules/wellness/wellness.dart';
import 'package:permission_handler/permission_handler.dart';

/// ACTIVITY_RECOGNITION ("Aktivitas fisik", Android 10+) through permission_handler, the
/// shell's permission plugin (ARCHITECTURE §9: permissions are requested only in shell).
/// Below Android 10 the plugin reports it as granted (no runtime permission there).
class ActivityRecognitionPermissions implements StepPermissions {
  const ActivityRecognitionPermissions();

  @override
  Future<bool> granted() => Permission.activityRecognition.isGranted;

  @override
  Future<bool> request() async =>
      (await Permission.activityRecognition.request()).isGranted;
}
