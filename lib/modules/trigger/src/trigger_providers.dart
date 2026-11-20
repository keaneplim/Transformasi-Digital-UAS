import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ui/qr_camera.dart';

/// The live QR camera (A02). Null until the composition root binds it (R8), so widget and
/// golden tests run without the camera plugin.
final qrCameraProvider = Provider<QrCameraBuilder?>((ref) => null);

/// Binding for the composition root: the mobile_scanner camera.
Override bindQrCamera() => qrCameraProvider.overrideWithValue(qrCameraBuilder);
