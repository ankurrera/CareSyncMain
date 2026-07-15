import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../../../core/theme/app_tokens.dart';

class BiometricScanHud extends StatefulWidget {
  final String status;
  final String label;
  final Widget? vector;

  const BiometricScanHud({
    super.key,
    required this.status,
    this.label = 'FACE ID SCAN',
    this.vector,
  });

  @override
  State<BiometricScanHud> createState() => _BiometricScanHudState();
}

class _BiometricScanHudState extends State<BiometricScanHud>
    with SingleTickerProviderStateMixin {
  late AnimationController _scannerController;

  @override
  void initState() {
    super.initState();
    _scannerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return Positioned.fill(
      child: ClipRect(
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            color: Colors.black.withValues(alpha: 0.55),
            child: Center(
              child: Container(
                width: 270,
                height: 240,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.12),
                    width: 1.0,
                  ),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 20,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    widget.vector ??
                        AnimatedBuilder(
                          animation: _scannerController,
                          builder: (context, child) {
                            return Stack(
                              alignment: Alignment.center,
                              children: [
                                SizedBox(
                                  width: 84,
                                  height: 84,
                                  child: CustomPaint(
                                    painter: FaceBracketPainter(
                                      color: t.accent,
                                      animationValue: _scannerController.value,
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  width: 44,
                                  height: 44,
                                  child: CustomPaint(
                                    painter: _FaceIdScannerPainter(
                                      color: Colors.white,
                                      animationValue: _scannerController.value,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                    const SizedBox(height: 20),
                    Text(
                      widget.label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'DM Sans',
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white60,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            widget.status,
                            style: const TextStyle(
                              fontFamily: 'DM Sans',
                              color: Colors.white60,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Apple Face ID-inspired camera corner brackets custom painter
class FaceBracketPainter extends CustomPainter {
  final Color color;
  final double animationValue;

  FaceBracketPainter({required this.color, required this.animationValue});

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = color.withValues(alpha: 0.3 + (animationValue * 0.7))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0
          ..strokeCap = StrokeCap.round;

    final length = 14.0;
    final r = 6.0;

    final pathTL =
        Path()
          ..moveTo(0, length)
          ..lineTo(0, r)
          ..quadraticBezierTo(0, 0, r, 0)
          ..lineTo(length, 0);
    canvas.drawPath(pathTL, paint);

    final pathTR =
        Path()
          ..moveTo(size.width, length)
          ..lineTo(size.width, r)
          ..quadraticBezierTo(size.width, 0, size.width - r, 0)
          ..lineTo(size.width - length, 0);
    canvas.drawPath(pathTR, paint);

    final pathBL =
        Path()
          ..moveTo(0, size.height - length)
          ..lineTo(0, size.height - r)
          ..quadraticBezierTo(0, size.height, r, size.height)
          ..lineTo(length, size.height);
    canvas.drawPath(pathBL, paint);

    final pathBR =
        Path()
          ..moveTo(size.width, size.height - length)
          ..lineTo(size.width, size.height - r)
          ..quadraticBezierTo(
            size.width,
            size.height,
            size.width - r,
            size.height,
          )
          ..lineTo(size.width - length, size.height);
    canvas.drawPath(pathBR, paint);
  }

  @override
  bool shouldRepaint(covariant FaceBracketPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.color != color;
  }
}

class _FaceIdScannerPainter extends CustomPainter {
  final Color color;
  final double animationValue;

  _FaceIdScannerPainter({required this.color, required this.animationValue});

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = color.withValues(alpha: 0.4 + (animationValue * 0.4))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0;

    final double w = size.width;
    final double h = size.height;

    final facePath =
        Path()
          ..moveTo(w * 0.35, h * 0.4)
          ..lineTo(w * 0.35, h * 0.42)
          ..moveTo(w * 0.65, h * 0.4)
          ..lineTo(w * 0.65, h * 0.42)
          ..moveTo(w * 0.5, h * 0.4)
          ..lineTo(w * 0.5, h * 0.55)
          ..lineTo(w * 0.58, h * 0.55)
          ..moveTo(w * 0.38, h * 0.68)
          ..quadraticBezierTo(w * 0.5, h * 0.76, w * 0.62, h * 0.68)
          ..moveTo(w * 0.25, h * 0.3)
          ..lineTo(w * 0.25, h * 0.58)
          ..quadraticBezierTo(w * 0.25, h * 0.85, w * 0.5, h * 0.85)
          ..quadraticBezierTo(w * 0.75, h * 0.85, w * 0.75, h * 0.58)
          ..lineTo(w * 0.75, h * 0.3);

    canvas.drawPath(facePath, paint);
  }

  @override
  bool shouldRepaint(covariant _FaceIdScannerPainter oldDelegate) =>
      oldDelegate.animationValue != animationValue ||
      oldDelegate.color != color;
}
