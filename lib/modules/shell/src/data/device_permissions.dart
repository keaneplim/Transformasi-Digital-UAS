import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

/// What Settings → "Izin ponsel" shows for one runtime permission.
enum PermissionState {
  granted,

  /// Not allowed yet; asking again shows the system dialog.
  denied,

  /// Refused for good ("Jangan tanya lagi", or twice on Android 11+): only the phone's
  /// app settings can change it.
  blocked,
}

/// Notifications and "Aktivitas fisik" status for Settings (PB07, T27), asked and re-asked
/// only from shell (ARCHITECTURE §9). Location has its own access check in `location`.
abstract interface class DevicePermissions {
  Future<PermissionState> notifications();
  Future<PermissionState> requestNotifications();
  Future<PermissionState> activity();
  Future<PermissionState> requestActivity();

  /// The app's page in the phone's settings.
  Future<void> openAppSettings();
}

/// Null until the composition root binds it (R8): tests, goldens and the web preview hide the
/// rows that need it.
final devicePermissionsProvider = Provider<DevicePermissions?>((ref) => null);

/// permission_handler (owned by shell, R5).
class PermissionHandlerPermissions implements DevicePermissions {
  const PermissionHandlerPermissions();

  static PermissionState _map(PermissionStatus s) => s.isGranted || s.isLimited
      ? PermissionState.granted
      : (s.isPermanentlyDenied || s.isRestricted)
          ? PermissionState.blocked
          : PermissionState.denied;

  @override
  Future<PermissionState> notifications() async =>
      _map(await Permission.notification.status);

  @override
  Future<PermissionState> requestNotifications() async =>
      _map(await Permission.notification.request());

  @override
  Future<PermissionState> activity() async =>
      _map(await Permission.activityRecognition.status);

  @override
  Future<PermissionState> requestActivity() async =>
      _map(await Permission.activityRecognition.request());

  @override
  Future<void> openAppSettings() async {
    await openAppSettingsPage();
  }
}

/// permission_handler's top-level `openAppSettings`, renamed so the method above can't
/// shadow it by accident.
Future<bool> openAppSettingsPage() => openAppSettings();
