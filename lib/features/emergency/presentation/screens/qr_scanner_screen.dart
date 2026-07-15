import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../../core/design/circular_icon_button.dart';
import '../../../../core/design/linear_fade_appbar.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../routing/route_names.dart';

class QrScannerScreen extends ConsumerStatefulWidget {
  const QrScannerScreen({super.key});

  @override
  ConsumerState<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends ConsumerState<QrScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
  );

  bool _isProcessing = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;

    final barcode = capture.barcodes.firstOrNull;
    if (barcode?.rawValue == null) return;

    final value = barcode!.rawValue!;

    // Check if it's a full URL or just a raw UUID
    String? qrCodeId;
    if (value.contains('/emergency/')) {
      final uri = Uri.parse(value);
      qrCodeId = uri.pathSegments.last;
    } else {
      final uuidRegex = RegExp(
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
      );
      if (uuidRegex.hasMatch(value)) {
        qrCodeId = value;
      }
    }

    if (qrCodeId != null) {
      setState(() => _isProcessing = true);
      if (mounted) {
        context.push('${RouteNames.patientEmergencyView}/$qrCodeId').then((_) {
          if (mounted) setState(() => _isProcessing = false);
        });
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Not a valid CareSync QR code'),
          backgroundColor: context.tokens.accent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          MobileScanner(controller: _controller, onDetect: _onDetect),
          CustomPaint(
            painter: _ScannerOverlayPainter(),
            child: const SizedBox.expand(),
          ),
          Positioned(
            bottom: 100,
            left: 0,
            right: 0,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Point camera at patient\'s\nCareSync QR code',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'DM Sans',
                      color: Colors.white,
                      fontSize: 15,
                    ),
                  ),
                ),
                if (_isProcessing) ...[
                  const SizedBox(height: 16),
                  const CircularProgressIndicator(color: Colors.white),
                ],
              ],
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LinearFadeAppBar(
              title: 'Scan Patient QR',
              actions: [
                ValueListenableBuilder(
                  valueListenable: _controller,
                  builder: (context, state, _) {
                    return CircularIconButton(
                      icon:
                          state.torchState == TorchState.on
                              ? Iconsax.flash_1
                              : Iconsax.flash_slash,
                      onTap: () => _controller.toggleTorch(),
                    );
                  },
                ),
                CircularIconButton(
                  icon: Iconsax.camera,
                  onTap: () => _controller.switchCamera(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ScannerOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black.withValues(alpha: 0.5);
    const windowSize = 280.0;
    final left = (size.width - windowSize) / 2;
    final top = (size.height - windowSize) / 2 - 50;
    final rect = Rect.fromLTWH(left, top, windowSize, windowSize);

    final path =
        Path()
          ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
          ..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(20)))
          ..fillType = PathFillType.evenOdd;

    canvas.drawPath(path, paint);

    final bracketPaint =
        Paint()
          ..color = Colors.white
          ..strokeWidth = 4
          ..style = PaintingStyle.stroke;

    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(20)),
      bracketPaint,
    );
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
