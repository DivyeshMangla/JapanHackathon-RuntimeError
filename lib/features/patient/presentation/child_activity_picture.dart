import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

enum ChildActivity { words, drawing }

/// Small vector illustrations retain their detail at larger display sizes.
class ChildActivityPicture extends StatelessWidget {
  const ChildActivityPicture({super.key, required this.activity});
  final ChildActivity activity;

  @override
  Widget build(BuildContext context) =>
      ExcludeSemantics(child: CustomPaint(painter: _ActivityPainter(activity)));
}

class _ActivityPainter extends CustomPainter {
  const _ActivityPainter(this.activity);
  final ChildActivity activity;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 100, size.height / 100);
    switch (activity) {
      case ChildActivity.words:
        _block(
          canvas,
          const Rect.fromLTWH(28, 35, 55, 43),
          AppColors.childMint,
          16,
        );
        _block(canvas, const Rect.fromLTWH(15, 20, 61, 46), AppColors.teal, 18);
        canvas.drawPath(
          Path()
            ..moveTo(22, 54)
            ..lineTo(22, 76)
            ..lineTo(41, 59)
            ..close(),
          Paint()..color = AppColors.teal,
        );
        _face(canvas, 45, 39);
      case ChildActivity.drawing:
        canvas.translate(49, 47);
        canvas.rotate(0.55);
        _block(
          canvas,
          const Rect.fromLTWH(-12, -30, 24, 54),
          AppColors.blossom,
          5,
        );
        _block(
          canvas,
          const Rect.fromLTWH(-12, -19, 24, 5),
          AppColors.childRose,
          0,
        );
        canvas.drawPath(
          Path()
            ..moveTo(-12, 24)
            ..lineTo(0, 43)
            ..lineTo(12, 24)
            ..close(),
          Paint()..color = AppColors.peach,
        );
        canvas.drawPath(
          Path()
            ..moveTo(-4, 36)
            ..lineTo(0, 43)
            ..lineTo(4, 36)
            ..close(),
          Paint()..color = AppColors.ink,
        );
        _face(canvas, 0, 0);
    }
  }

  void _block(Canvas canvas, Rect rect, Color color, double radius) =>
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(radius)),
        Paint()..color = color,
      );

  void _face(Canvas canvas, double x, double y) {
    final ink = Paint()..color = AppColors.ink;
    canvas.drawCircle(Offset(x - 7, y), 2.4, ink);
    canvas.drawCircle(Offset(x + 7, y), 2.4, ink);
    canvas.drawPath(
      Path()
        ..moveTo(x - 5, y + 7)
        ..quadraticBezierTo(x, y + 12, x + 5, y + 7),
      Paint()
        ..color = AppColors.ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_ActivityPainter oldDelegate) =>
      oldDelegate.activity != activity;
}
