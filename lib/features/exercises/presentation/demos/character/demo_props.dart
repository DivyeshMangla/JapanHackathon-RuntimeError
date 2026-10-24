import 'package:flutter/painting.dart';

import 'demo_style.dart';

/// Scenery and effects shared by the exercise illustrations, in design
/// space.
abstract final class DemoProps {
  /// An exercise mat seen slightly from above, with its top face spanning
  /// [left] to [right] and its near edge at [front].
  static void mat(
    Canvas canvas, {
    required double left,
    required double right,
    required double front,
  }) {
    const depth = 14.0;
    const slant = 8.0;
    const thickness = 3.0;
    final top = Path()
      ..moveTo(left + slant, front - depth)
      ..lineTo(right + slant, front - depth)
      ..lineTo(right, front)
      ..lineTo(left, front)
      ..close();
    final edge = Path()
      ..moveTo(left, front)
      ..lineTo(right, front)
      ..lineTo(right, front + thickness)
      ..lineTo(left, front + thickness)
      ..close();
    canvas
      ..drawPath(edge, DemoStyle.ink)
      ..drawPath(top, DemoStyle.mat)
      ..drawPath(top, DemoStyle.outline);
  }

  /// Flat contact shadow under a body resting on a surface.
  static void shadow(Canvas canvas, Rect area) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(area, Radius.circular(area.height / 2)),
      DemoStyle.ink,
    );
  }

  /// A soft oval wash behind the scene.
  static void backdrop(Canvas canvas, Rect area) =>
      canvas.drawOval(area, DemoStyle.backdrop);

  /// Two faint arcs stacked above [point], marking the part of the body
  /// that moves without suggesting a big or forced movement.
  static void riseMarks(Canvas canvas, Offset point) {
    final paint = DemoStyle.motion(0.25);
    for (var i = 0; i < 2; i++) {
      final y = point.dy - i * 4;
      canvas.drawPath(
        Path()
          ..moveTo(point.dx - 5, y + 1)
          ..quadraticBezierTo(point.dx, y - 1, point.dx + 5, y + 1),
        paint,
      );
    }
  }

  /// A small chevron at [tip] pointing along [direction] (radians), for
  /// air moving in or out.
  static void chevron(
    Canvas canvas,
    Offset tip,
    double direction,
    double opacity,
  ) {
    if (opacity <= 0) return;
    const arm = 3.2;
    final left = tip - Offset.fromDirection(direction - 0.7, arm);
    final right = tip - Offset.fromDirection(direction + 0.7, arm);
    final mark = Path()
      ..moveTo(left.dx, left.dy)
      ..lineTo(tip.dx, tip.dy)
      ..lineTo(right.dx, right.dy);
    canvas.drawPath(mark, DemoStyle.motion(opacity));
  }
}
