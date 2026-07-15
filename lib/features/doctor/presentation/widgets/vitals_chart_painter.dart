import 'dart:math';
import 'package:flutter/material.dart';

class VitalsChartPainter extends CustomPainter {
  final List<double> values;
  final List<double>? secondaryValues; // For diastolic BP
  final Color color;
  final Color? secondaryColor;
  final Color ringColor;

  VitalsChartPainter({
    required this.values,
    this.secondaryValues,
    required this.color,
    this.secondaryColor,
    required this.ringColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;

    final paint =
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.3
          ..strokeCap = StrokeCap.round;

    // Find min and max for scaling
    double minVal = values.reduce(min);
    double maxVal = values.reduce(max);
    if (secondaryValues != null && secondaryValues!.isNotEmpty) {
      final minSec = secondaryValues!.reduce(min);
      final maxSec = secondaryValues!.reduce(max);
      minVal = min(minVal, minSec);
      maxVal = max(maxVal, maxSec);
    }

    // Add padding to min/max
    final range = maxVal - minVal;
    minVal = minVal - (range * 0.15);
    maxVal = maxVal + (range * 0.15);
    if (maxVal == minVal) {
      minVal -= 10;
      maxVal += 10;
    }

    final double width = size.width;
    final double height = size.height;

    // Draw main line
    final points = <Offset>[];
    if (values.length == 1) {
      points.add(Offset(0, height / 2));
      points.add(Offset(width, height / 2));
    } else {
      for (int i = 0; i < values.length; i++) {
        final x = (i / (values.length - 1)) * width;
        final y = height - ((values[i] - minVal) / (maxVal - minVal)) * height;
        points.add(Offset(x, y));
      }
    }

    _drawSmoothLine(canvas, points, paint, size, color);

    // Draw secondary line if provided
    if (secondaryValues != null && secondaryValues!.length == values.length) {
      final secPaint =
          Paint()
            ..color = secondaryColor ?? color.withValues(alpha: 0.5)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..strokeCap = StrokeCap.round;

      final secPoints = <Offset>[];
      if (secondaryValues!.length == 1) {
        secPoints.add(Offset(0, height / 2));
        secPoints.add(Offset(width, height / 2));
      } else {
        for (int i = 0; i < secondaryValues!.length; i++) {
          final x = (i / (secondaryValues!.length - 1)) * width;
          final y =
              height -
              ((secondaryValues![i] - minVal) / (maxVal - minVal)) * height;
          secPoints.add(Offset(x, y));
        }
      }

      _drawSmoothLine(
        canvas,
        secPoints,
        secPaint,
        size,
        secondaryColor ?? color.withValues(alpha: 0.5),
        fill: false,
      );
    }
  }

  void _drawSmoothLine(
    Canvas canvas,
    List<Offset> points,
    Paint paint,
    Size size,
    Color lineColor, {
    bool fill = true,
  }) {
    if (points.isEmpty) return;

    final path = Path();
    path.moveTo(points[0].dx, points[0].dy);

    if (points.length == 1) {
      canvas.drawCircle(points[0], 3.0, paint..style = PaintingStyle.fill);
      return;
    }

    for (int i = 0; i < points.length - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];
      final controlPoint1 = Offset(p0.dx + (p1.dx - p0.dx) / 2, p0.dy);
      final controlPoint2 = Offset(p0.dx + (p1.dx - p0.dx) / 2, p1.dy);
      path.cubicTo(
        controlPoint1.dx,
        controlPoint1.dy,
        controlPoint2.dx,
        controlPoint2.dy,
        p1.dx,
        p1.dy,
      );
    }

    canvas.drawPath(path, paint);

    // Fill area under the curve
    if (fill && points.length > 1) {
      final fillPath = Path.from(path);
      fillPath.lineTo(size.width, size.height);
      fillPath.lineTo(0, size.height);
      fillPath.close();

      final fillPaint =
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                lineColor.withValues(alpha: 0.15),
                lineColor.withValues(alpha: 0.00),
              ],
            ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
            ..style = PaintingStyle.fill;

      canvas.drawPath(fillPath, fillPaint);
    }

    // Draw a small dot on the last point
    final dotPaint =
        Paint()
          ..color = lineColor
          ..style = PaintingStyle.fill;
    canvas.drawCircle(points.last, 3.5, dotPaint);

    final ringPaint =
        Paint()
          ..color = ringColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0;
    canvas.drawCircle(points.last, 3.5, ringPaint);
  }

  @override
  bool shouldRepaint(covariant VitalsChartPainter oldDelegate) {
    return oldDelegate.values != values ||
        oldDelegate.secondaryValues != secondaryValues;
  }
}
