import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatting.dart';
import '../../../core/utils/l10n.dart';
import '../domain/adherence.dart';

/// Column chart of completion rate per period (day or week). Tap a column to
/// read its exact values; the latest period is selected to start.
class CompletionChart extends StatefulWidget {
  const CompletionChart({
    super.key,
    required this.periods,
    required this.axisLabel,
    required this.detailLabel,
    this.height = 180,
  });

  final List<AdherencePeriod> periods;

  /// Short label under a column, e.g. "M" or "6/10". Empty to skip.
  final String Function(AdherencePeriod period) axisLabel;

  /// Heading for the selected period, e.g. "Tue 6 Oct".
  final String Function(AdherencePeriod period) detailLabel;
  final double height;

  @override
  State<CompletionChart> createState() => _CompletionChartState();
}

class _CompletionChartState extends State<CompletionChart> {
  late int _selected = widget.periods.length - 1;

  static const _axisWidth = 36.0;

  @override
  void didUpdateWidget(CompletionChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.periods.length != widget.periods.length) {
      _selected = widget.periods.length - 1;
    }
  }

  void _select(Offset position, double plotWidth) {
    final slot = plotWidth / widget.periods.length;
    final index = ((position.dx - _axisWidth) / slot).floor();
    if (index >= 0 && index < widget.periods.length && index != _selected) {
      setState(() => _selected = index);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final selected = widget.periods[_selected];
    final l10n = context.l10n;
    final caption = selected.due == 0
        ? l10n.chartNothing
        : l10n.chartDone(
            selected.done,
            selected.due,
            formatPercent(selected.rate),
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: AppColors.washTint,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Text(widget.detailLabel(selected), style: text.labelMedium),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(caption, style: text.titleMedium),
        const SizedBox(height: AppSpacing.md),
        LayoutBuilder(
          builder: (context, constraints) {
            final plotWidth = constraints.maxWidth - _axisWidth;
            return Semantics(
              label: l10n.chartSemantics(widget.detailLabel(selected), caption),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (d) => _select(d.localPosition, plotWidth),
                onHorizontalDragUpdate: (d) =>
                    _select(d.localPosition, plotWidth),
                child: CustomPaint(
                  size: Size(constraints.maxWidth, widget.height),
                  painter: _ChartPainter(
                    periods: widget.periods,
                    selected: _selected,
                    axisWidth: _axisWidth,
                    labels: [
                      for (final p in widget.periods) widget.axisLabel(p),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _ChartPainter extends CustomPainter {
  _ChartPainter({
    required this.periods,
    required this.selected,
    required this.axisWidth,
    required this.labels,
  });

  final List<AdherencePeriod> periods;
  final int selected;
  final double axisWidth;
  final List<String> labels;

  static const _labelBand = 22.0;
  static const _maxBar = 24.0;
  static const _gap = 2.0;

  @override
  void paint(Canvas canvas, Size size) {
    final plotHeight = size.height - _labelBand;
    final plotWidth = size.width - axisWidth;
    final grid = Paint()
      ..color = AppColors.hairline
      ..strokeWidth = 1;

    for (final fraction in const [0.0, 0.5, 1.0]) {
      final y = plotHeight * (1 - fraction);
      canvas.drawLine(Offset(axisWidth, y), Offset(size.width, y), grid);
      _text(
        canvas,
        '${(fraction * 100).round()}%',
        Offset(0, y - 7),
        width: axisWidth - 6,
        align: TextAlign.right,
      );
    }

    final slot = plotWidth / periods.length;
    final barWidth = (slot - _gap).clamp(2.0, _maxBar);
    for (var i = 0; i < periods.length; i++) {
      final centerX = axisWidth + slot * i + slot / 2;
      final rate = periods[i].rate;
      final isSelected = i == selected;
      final color = isSelected
          ? AppColors.ink
          : AppColors.seal.withValues(alpha: 0.24);
      if (isSelected) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(centerX - slot / 2, 0, slot, size.height),
            const Radius.circular(AppRadius.small),
          ),
          Paint()..color = AppColors.sunshine.withValues(alpha: 0.35),
        );
      }

      if (rate == null) {
        canvas.drawLine(
          Offset(centerX - barWidth / 2, plotHeight - 1),
          Offset(centerX + barWidth / 2, plotHeight - 1),
          Paint()
            ..color = AppColors.wash
            ..strokeWidth = 2,
        );
      } else if (rate == 0) {
        // Nothing done: a short baseline mark keeps the column selectable
        // and visible.
        canvas.drawLine(
          Offset(centerX - barWidth / 2, plotHeight - 1),
          Offset(centerX + barWidth / 2, plotHeight - 1),
          Paint()
            ..color = color
            ..strokeWidth = 3,
        );
      } else {
        final top = plotHeight * (1 - rate);
        final radius = (barWidth / 2).clamp(0.0, AppRadius.small);
        canvas.drawRRect(
          RRect.fromRectAndCorners(
            Rect.fromLTRB(
              centerX - barWidth / 2,
              top,
              centerX + barWidth / 2,
              plotHeight,
            ),
            topLeft: Radius.circular(radius),
            topRight: Radius.circular(radius),
          ),
          Paint()..color = color,
        );
      }

      if (labels[i].isNotEmpty) {
        _text(
          canvas,
          labels[i],
          Offset(centerX - slot / 2, plotHeight + 6),
          width: slot,
          align: TextAlign.center,
          color: isSelected ? AppColors.ink : AppColors.muted,
        );
      }
    }
  }

  void _text(
    Canvas canvas,
    String value,
    Offset offset, {
    required double width,
    required TextAlign align,
    Color color = AppColors.muted,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: value,
        style: AppTypography.monoMicro.copyWith(color: color),
      ),
      textAlign: align,
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout(minWidth: width, maxWidth: width);
    painter.paint(canvas, offset);
    painter.dispose();
  }

  @override
  bool shouldRepaint(_ChartPainter oldDelegate) =>
      oldDelegate.selected != selected || oldDelegate.periods != periods;
}
