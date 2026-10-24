import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/l10n.dart';
import '../../../shared/widgets/buttons.dart';
import '../domain/motor.dart';

/// Animates the guide strokes so the child can watch before drawing.
class MotorDemo extends StatefulWidget {
  const MotorDemo({super.key, required this.exercise});
  final MotorExercise exercise;
  @override
  State<MotorDemo> createState() => _MotorDemoState();
}

class _MotorDemoState extends State<MotorDemo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  );
  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.motorWatch, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSpacing.sm),
        Semantics(
          label: l10n.motorDemoDescription,
          image: true,
          child: SizedBox(
            height: AppSizes.signaturePad,
            child: Center(
              // The normalized guides use a 3:2 board so circles stay round on tablets.
              child: AspectRatio(
                aspectRatio: 1.5,
                child: AnimatedBuilder(
                  animation: _animation,
                  builder: (_, _) => CustomPaint(
                    painter: _StrokePainter(
                      widget.exercise.strokes,
                      _animation.isDismissed ? 1 : _animation.value,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        SecondaryButton(
          label: l10n.motorReplay,
          onPressed: () {
            if (MediaQuery.disableAnimationsOf(context)) {
              _animation.value = 1;
            } else {
              _animation.forward(from: 0);
            }
          },
        ),
        for (var i = 0; i < widget.exercise.steps.length; i++)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.md),
            child: Text('${i + 1}. ${widget.exercise.steps[i]}'),
          ),
      ],
    );
  }
}

class _StrokePainter extends CustomPainter {
  _StrokePainter(this.strokes, this.progress);
  final List<List<List<double>>> strokes;
  final double progress;
  @override
  void paint(Canvas canvas, Size size) {
    final guide = Paint()
      ..color = AppColors.wash
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final ink = Paint()
      ..color = AppColors.ink
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 4;
    for (var i = 0; i < strokes.length; i++) {
      final stroke = strokes[i];
      if (stroke.length < 2) continue;
      final path = Path()
        ..moveTo(stroke.first[0] * size.width, stroke.first[1] * size.height);
      for (final point in stroke.skip(1)) {
        path.lineTo(point[0] * size.width, point[1] * size.height);
      }
      canvas.drawPath(path, guide);
      final fraction = (progress * strokes.length - i).clamp(0.0, 1.0);
      final metric = path.computeMetrics().first;
      canvas.drawPath(metric.extractPath(0, metric.length * fraction), ink);
      final position = metric
          .getTangentForOffset(metric.length * fraction)
          ?.position;
      if (position != null && fraction < 1) {
        canvas.drawCircle(
          position,
          AppSpacing.sm,
          Paint()..color = AppColors.ink,
        );
      }
      canvas.drawCircle(
        Offset(stroke.first[0] * size.width, stroke.first[1] * size.height),
        AppSpacing.xs,
        Paint()..color = AppColors.ink,
      );
    }
  }

  @override
  bool shouldRepaint(_StrokePainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.strokes != strokes;
}
