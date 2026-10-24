import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../domain/expression.dart';

/// Two illustrations per label share facial cues but differ in shape and detail.
class ExpressionFace extends StatelessWidget {
  const ExpressionFace({
    super.key,
    required this.picture,
    required this.semanticLabel,
    this.size = AppSizes.signaturePad,
  });

  final ExpressionPicture picture;
  final String semanticLabel;
  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label: semanticLabel,
    child: ExcludeSemantics(
      child: CustomPaint(
        size: Size.square(size),
        painter: _ExpressionPainter(picture),
      ),
    ),
  );
}

class _ExpressionPainter extends CustomPainter {
  const _ExpressionPainter(this.picture);
  final ExpressionPicture picture;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 100, size.height / 100);
    final fill = Paint()
      ..color = picture.variant == 1 ? AppColors.childButter : AppColors.peach;
    final line = Paint()
      ..color = AppColors.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    canvas.drawOval(
      Rect.fromCenter(
        center: const Offset(50, 50),
        width: picture.variant == 1 ? 76 : 72,
        height: 82,
      ),
      fill,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: const Offset(50, 50),
        width: picture.variant == 1 ? 76 : 72,
        height: 82,
      ),
      line,
    );
    final hair = Path()
      ..moveTo(22, 25)
      ..quadraticBezierTo(35, 4, 51, 11)
      ..quadraticBezierTo(64, 2, 78, 25);
    canvas.drawPath(hair, line);
    if (picture.variant == 2) {
      canvas.drawPath(
        Path()
          ..moveTo(33, 13)
          ..quadraticBezierTo(28, 28, 23, 30),
        line,
      );
      canvas.drawPath(
        Path()
          ..moveTo(65, 13)
          ..quadraticBezierTo(72, 28, 78, 30),
        line,
      );
    }
    final variation = picture.variant == 2 ? 4.0 : 0.0;
    if (picture.feeling == Feeling.calm) {
      canvas.drawArc(
        const Rect.fromLTWH(28, 37, 15, 10),
        0,
        math.pi,
        false,
        line,
      );
      canvas.drawArc(
        const Rect.fromLTWH(57, 37, 15, 10),
        0,
        math.pi,
        false,
        line,
      );
    } else {
      final wide =
          picture.feeling == Feeling.scared ||
          picture.feeling == Feeling.surprised;
      for (final x in [35.0, 65.0]) {
        if (wide) {
          canvas.drawOval(
            Rect.fromCenter(center: Offset(x, 45), width: 11, height: 15),
            line,
          );
        }
        canvas.drawCircle(
          Offset(x, 45),
          wide ? 2 : 3,
          Paint()..color = AppColors.ink,
        );
      }
    }
    switch (picture.feeling) {
      case Feeling.happy:
      case Feeling.calm:
        canvas.drawPath(
          Path()
            ..moveTo(35, 63)
            ..quadraticBezierTo(
              50,
              picture.feeling == Feeling.happy
                  ? 83 - variation
                  : 72 - variation,
              65,
              63,
            ),
          line,
        );
      case Feeling.sad:
        canvas.drawPath(
          Path()
            ..moveTo(35, 73)
            ..quadraticBezierTo(50, 57 - variation, 65, 73),
          line,
        );
        canvas.drawLine(const Offset(28, 34), const Offset(42, 29), line);
        canvas.drawLine(const Offset(58, 29), const Offset(72, 34), line);
        canvas.drawPath(
          Path()
            ..moveTo(26, 53)
            ..quadraticBezierTo(18, 66, 27, 64)
            ..quadraticBezierTo(32, 63, 26, 53),
          Paint()..color = AppColors.wash,
        );
      case Feeling.angry:
        canvas.drawLine(const Offset(27, 30), const Offset(43, 38), line);
        canvas.drawLine(const Offset(57, 38), const Offset(73, 30), line);
        canvas.drawPath(
          Path()
            ..moveTo(35, 73)
            ..quadraticBezierTo(50, 60 - variation, 65, 73),
          line,
        );
      case Feeling.surprised:
        canvas.drawArc(
          const Rect.fromLTWH(27, 26, 16, 12),
          math.pi,
          math.pi,
          false,
          line,
        );
        canvas.drawArc(
          const Rect.fromLTWH(57, 26, 16, 12),
          math.pi,
          math.pi,
          false,
          line,
        );
        canvas.drawOval(
          Rect.fromLTWH(43 - variation / 2, 61, 14 + variation, 20 - variation),
          line,
        );
      case Feeling.scared:
        canvas.drawLine(const Offset(27, 34), const Offset(43, 27), line);
        canvas.drawLine(const Offset(57, 27), const Offset(73, 34), line);
        canvas.drawPath(
          Path()
            ..moveTo(35, 70)
            ..quadraticBezierTo(39, 62, 44, 68)
            ..quadraticBezierTo(49, 60 - variation, 54, 68)
            ..quadraticBezierTo(60, 62, 65, 70),
          line,
        );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ExpressionPainter oldDelegate) =>
      oldDelegate.picture.id != picture.id;
}
