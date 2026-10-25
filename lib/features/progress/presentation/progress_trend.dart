import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/formatting.dart';
import '../domain/family_progress.dart';
import 'progress_strings.dart';

/// Week-by-week scores for one activity as a line graph, so a family can see
/// change over time rather than a single running total.
class ProgressTrend extends StatelessWidget {
  const ProgressTrend({super.key, required this.progress});

  final ActivityProgress progress;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scored = progress.scoredWeeks;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          ProgressStrings.activity(progress.activity),
          style: text.titleMedium,
        ),
        const SizedBox(height: AppSpacing.xs),
        if (scored.length < 2)
          Text(ProgressStrings.trendTooEarly, style: text.bodySmall)
        else ...[
          Text(
            ProgressStrings.trendChange(
              scored.first.score!,
              scored.last.score!,
            ),
            style: text.titleLarge?.copyWith(
              color: scored.last.score! >= scored.first.score!
                  ? AppColors.teal
                  : AppColors.ink,
            ),
          ),
          Text(
            ProgressStrings.trendGoal(progress.activity),
            style: text.bodySmall,
          ),
          const SizedBox(height: AppSpacing.md),
          Semantics(
            container: true,
            image: true,
            label: ProgressStrings.trendSemantics(scored),
            child: ExcludeSemantics(
              child: SizedBox(
                height: AppSizes.trendChart,
                width: double.infinity,
                child: CustomPaint(
                  painter: _TrendPainter(
                    weeks: progress.trend,
                    labelStyle: text.labelSmall!.copyWith(
                      color: AppColors.muted,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _TrendPainter extends CustomPainter {
  _TrendPainter({required this.weeks, required this.labelStyle});

  final List<WeeklyProgress> weeks;
  final TextStyle labelStyle;

  static const _axisWidth = AppSpacing.xl;
  static const _lineWidth = 3.0;
  static const _pointRadius = 5.0;

  TextPainter _label(String value) => TextPainter(
    text: TextSpan(text: value, style: labelStyle),
    textDirection: TextDirection.ltr,
  )..layout();

  @override
  void paint(Canvas canvas, Size size) {
    final dateHeight = _label('0').height + AppSpacing.sm;
    final top = _pointRadius + AppSpacing.xs;
    final plot = Rect.fromLTRB(
      _axisWidth,
      top,
      size.width - _pointRadius,
      size.height - dateHeight,
    );
    final grid = Paint()
      ..color = AppColors.hairline
      ..strokeWidth = 1;
    for (final percent in const [0, 50, 100]) {
      final y = plot.bottom - plot.height * percent / 100;
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), grid);
      final label = _label('$percent%');
      label.paint(canvas, Offset(0, y - label.height / 2));
    }

    final step = weeks.length > 1 ? plot.width / (weeks.length - 1) : 0.0;
    Offset? previous;
    final points = <Offset>[];
    final line = Paint()
      ..color = AppColors.ink
      ..strokeWidth = _lineWidth
      ..strokeCap = StrokeCap.round;
    for (final (index, week) in weeks.indexed) {
      final x = plot.left + step * index;
      final date = _label(formatShortDate(week.weekStart));
      final dateX = (x - date.width / 2).clamp(0.0, size.width - date.width);
      // Only the first, last and every other week are labelled so dates fit
      // on a narrow phone.
      if (index == 0 || index == weeks.length - 1 || index.isEven) {
        date.paint(canvas, Offset(dateX, plot.bottom + AppSpacing.sm));
      }
      final score = week.score;
      if (score == null) continue;
      final point = Offset(x, plot.bottom - plot.height * score / 100);
      if (previous != null) canvas.drawLine(previous, point, line);
      previous = point;
      points.add(point);
    }
    final fill = Paint()..color = AppColors.sunshine;
    for (final (index, point) in points.indexed) {
      final radius = index == points.length - 1
          ? _pointRadius + 2
          : _pointRadius;
      canvas
        ..drawCircle(point, radius, fill)
        ..drawCircle(
          point,
          radius,
          Paint()
            ..color = AppColors.ink
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
    }
  }

  @override
  bool shouldRepaint(_TrendPainter oldDelegate) =>
      oldDelegate.weeks != weeks || oldDelegate.labelStyle != labelStyle;
}
