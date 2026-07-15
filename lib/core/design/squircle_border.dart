import 'package:flutter/material.dart';

/// A superellipse ("squircle") [ShapeBorder].
///
/// Each corner is a single cubic Bézier whose control points sit at the rect's
/// true corner — so the curve reads noticeably softer than a circular corner of
/// the same numeric radius (hence the large radius values used across the app:
/// 36 / 52 / 80). Optional [side] paints a hairline stroke along the shape.
///
/// Use the *same* instance for both `ClipPath.shape` and `InkWell.customBorder`
/// so ripples clip exactly to the corner.
class SquircleBorder extends ShapeBorder {
  const SquircleBorder({this.radius = 52, this.side = BorderSide.none});

  final double radius;
  final BorderSide side;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(side.width);

  double _effectiveRadius(Rect rect) =>
      radius.clamp(0.0, rect.shortestSide / 2);

  Path _path(Rect rect) {
    final r = _effectiveRadius(rect);
    final l = rect.left, t = rect.top, rt = rect.right, b = rect.bottom;
    return Path()
      ..moveTo(l + r, t)
      ..lineTo(rt - r, t)
      ..cubicTo(rt, t, rt, t, rt, t + r) // top-right
      ..lineTo(rt, b - r)
      ..cubicTo(rt, b, rt, b, rt - r, b) // bottom-right
      ..lineTo(l + r, b)
      ..cubicTo(l, b, l, b, l, b - r) // bottom-left
      ..lineTo(l, t + r)
      ..cubicTo(l, t, l, t, l + r, t) // top-left
      ..close();
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) => _path(rect);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      _path(rect.deflate(side.width));

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (side.style == BorderStyle.none || side.width == 0) return;
    final paint =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = side.width
          ..color = side.color;
    canvas.drawPath(getOuterPath(rect.deflate(side.width / 2)), paint);
  }

  @override
  ShapeBorder scale(double t) =>
      SquircleBorder(radius: radius * t, side: side.scale(t));

  SquircleBorder copyWith({double? radius, BorderSide? side}) =>
      SquircleBorder(radius: radius ?? this.radius, side: side ?? this.side);

  @override
  ShapeBorder? lerpFrom(ShapeBorder? a, double t) {
    if (a is SquircleBorder) {
      return SquircleBorder(
        radius: lerpDouble(a.radius, radius, t),
        side: BorderSide.lerp(a.side, side, t),
      );
    }
    return super.lerpFrom(a, t);
  }

  @override
  ShapeBorder? lerpTo(ShapeBorder? b, double t) {
    if (b is SquircleBorder) {
      return SquircleBorder(
        radius: lerpDouble(radius, b.radius, t),
        side: BorderSide.lerp(side, b.side, t),
      );
    }
    return super.lerpTo(b, t);
  }

  @override
  bool operator ==(Object other) =>
      other is SquircleBorder && other.radius == radius && other.side == side;

  @override
  int get hashCode => Object.hash(radius, side);

  static double lerpDouble(double a, double b, double t) => a + (b - a) * t;
}
