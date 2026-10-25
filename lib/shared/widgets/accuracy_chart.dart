import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';

/// One measure from 0 to 1. A null value could not be assessed and is drawn
/// as an empty track.
class AccuracyMeasure {
  const AccuracyMeasure(this.label, this.value);

  final String label;
  final double? value;
}

/// A headline percentage, the mean of the assessable measures, above one bar
/// per measure.
class AccuracyChart extends StatelessWidget {
  const AccuracyChart({
    super.key,
    required this.title,
    required this.measures,
    required this.notAssessable,
  });

  final String title;
  final List<AccuracyMeasure> measures;

  /// Shown in place of a percentage for a measure without a value.
  final String notAssessable;

  static String percent(double value) => '${(value * 100).round()}%';

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final values = [
      for (final measure in measures)
        if (measure.value != null) measure.value!,
    ];
    final overall = values.isEmpty
        ? null
        : values.reduce((a, b) => a + b) / values.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          label: '$title ${overall == null ? notAssessable : percent(overall)}',
          excludeSemantics: true,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(child: Text(title, style: text.titleSmall)),
              Text(
                overall == null ? notAssessable : percent(overall),
                style: text.headlineMedium,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        for (final measure in measures)
          _AccuracyBar(measure: measure, notAssessable: notAssessable),
      ],
    );
  }
}

class _AccuracyBar extends StatelessWidget {
  const _AccuracyBar({required this.measure, required this.notAssessable});

  final AccuracyMeasure measure;
  final String notAssessable;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final value = measure.value?.clamp(0.0, 1.0);
    final shown = value == null ? notAssessable : AccuracyChart.percent(value);
    return Semantics(
      label: '${measure.label} $shown',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text(measure.label, style: text.labelMedium)),
                Text(shown, style: text.labelMedium),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: SizedBox(
                height: AppSizes.chartBar,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    const ColoredBox(color: AppColors.washTint),
                    if (value != null)
                      FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: value,
                        child: const ColoredBox(color: AppColors.sunshine),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
