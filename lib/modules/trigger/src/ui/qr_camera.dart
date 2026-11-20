import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Why the camera can't scan; the screen shows a way out (Pilih manual, UC-A02-3).
enum QrCameraProblem { permissionDenied, unavailable }

/// Builds the live camera for UI12. Bound in the composition root ([bindQrCamera]); null in
/// tests and the web preview, where the screen falls back to its list of codes.
typedef QrCameraBuilder = Widget Function({
  required ValueChanged<String> onCode,
  required bool torch,
  required Widget Function(QrCameraProblem problem) problemBuilder,
});

/// Live QR camera (A02) on mobile_scanner: QR codes only, back camera, works offline (the
/// Android ML Kit model is bundled in the APK). Every decoded payload goes to [onCode]; the
/// screen decides what it means. Pause/resume with the app is handled by the plugin.
class QrCamera extends StatefulWidget {
  const QrCamera({
    super.key,
    required this.onCode,
    required this.torch,
    required this.problemBuilder,
  });

  final ValueChanged<String> onCode;

  /// Cave mode: the torch follows this flag.
  final bool torch;
  final Widget Function(QrCameraProblem problem) problemBuilder;

  @override
  State<QrCamera> createState() => _QrCameraState();
}

class _QrCameraState extends State<QrCamera> {
  final _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  @override
  void didUpdateWidget(QrCamera old) {
    super.didUpdateWidget(old);
    if (old.torch != widget.torch) _syncTorch();
  }

  Future<void> _syncTorch() async {
    final on = _controller.value.torchState == TorchState.on;
    if (on == widget.torch) return;
    try {
      await _controller.toggleTorch();
    } on Object {
      // No torch on this phone, or the camera isn't running yet: the button just does nothing.
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MobileScanner(
        controller: _controller,
        onDetect: (capture) {
          for (final b in capture.barcodes) {
            final raw = b.rawValue;
            if (raw != null && raw.isNotEmpty) widget.onCode(raw);
          }
        },
        errorBuilder: (context, error) => widget.problemBuilder(
            error.errorCode == MobileScannerErrorCode.permissionDenied
                ? QrCameraProblem.permissionDenied
                : QrCameraProblem.unavailable),
      );
}

/// For [qrCameraProvider] in the composition root.
QrCameraBuilder get qrCameraBuilder =>
    ({required onCode, required torch, required problemBuilder}) =>
        QrCamera(onCode: onCode, torch: torch, problemBuilder: problemBuilder);
