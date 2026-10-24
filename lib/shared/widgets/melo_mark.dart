import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// The Melo mark: the smiling "o" of the wordmark with three drops of
/// expression rising from it. Drawn on a 100 unit grid so the launcher icon
/// generator and the in-app mark stay identical.
class MeloMark extends StatelessWidget {
  const MeloMark({super.key, required this.size});

  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: CustomPaint(
      size: Size.square(size),
      painter: const MeloMarkPainter(),
    ),
  );
}

/// A teardrop whose round end sits at [center] and whose tip points along
/// [degrees], [length] units away.
class _Drop {
  const _Drop(this.center, this.radius, this.length, this.degrees, this.color);

  final Offset center;
  final double radius;
  final double length;
  final double degrees;
  final Color color;

  Path get path {
    final r = radius;
    final l = length;
    return Path()
      ..moveTo(-r, 0)
      ..arcToPoint(Offset(0, -r), radius: Radius.circular(r))
      ..cubicTo(l * 0.45, -r, l * 0.82, -r * 0.42, l, 0)
      ..cubicTo(l * 0.82, r * 0.42, l * 0.45, r, 0, r)
      ..arcToPoint(Offset(-r, 0), radius: Radius.circular(r))
      ..close();
  }
}

class MeloMarkPainter extends CustomPainter {
  const MeloMarkPainter();

  static const grid = 100.0;
  static const ringCenter = Offset(42.1, 69.4);
  static const ringRadius = 23.0;
  static const ringStroke = 11.0;

  static const _drops = [
    _Drop(Offset(36.6, 9.2), 7.4, 22.6, 86, AppColors.sunshine),
    _Drop(Offset(61.5, 17.4), 7.4, 21.6, 122, AppColors.teal),
    _Drop(Offset(78.8, 39.2), 7.7, 17.5, 165, AppColors.orchid),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / grid);
    for (final drop in _drops) {
      canvas
        ..save()
        ..translate(drop.center.dx, drop.center.dy)
        ..rotate(drop.degrees * math.pi / 180)
        ..drawPath(drop.path, Paint()..color = drop.color)
        ..restore();
    }
    canvas.drawCircle(
      ringCenter,
      ringRadius,
      Paint()
        ..color = AppColors.ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = ringStroke,
    );
    final feature = Paint()..color = AppColors.ink;
    final smile = Path()
      ..moveTo(ringCenter.dx - 6.5, ringCenter.dy + 6.7)
      ..quadraticBezierTo(
        ringCenter.dx,
        ringCenter.dy + 13,
        ringCenter.dx + 6.5,
        ringCenter.dy + 6.7,
      );
    canvas
      ..drawCircle(
        Offset(ringCenter.dx - 7.8, ringCenter.dy - 3.3),
        2.6,
        feature,
      )
      ..drawCircle(
        Offset(ringCenter.dx + 7.8, ringCenter.dy - 3.3),
        2.6,
        feature,
      )
      ..drawPath(
        smile,
        Paint()
          ..color = AppColors.ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.4
          ..strokeCap = StrokeCap.round,
      );
  }

  @override
  bool shouldRepaint(MeloMarkPainter old) => false;
}
