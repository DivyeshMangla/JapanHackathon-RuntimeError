import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/formatting.dart';
import '../domain/family_progress.dart';
import 'progress_strings.dart';

/// Week-by-week scores for one activity, so a family can see change over time
/// rather than a single running total.
class ProgressTrend extends StatelessWidget {
  const ProgressTrend({super.key, required this.progress});

  final ActivityProgress progress;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scored = progress.scoredWeeks;
    if (scored.length < 2) {
      return Text(ProgressStrings.trendTooEarly, style: text.bodySmall);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(ProgressStrings.trendTitle, style: text.labelLarge),
        const SizedBox(height: AppSpacing.xs),
        Text(
          ProgressStrings.trendChange(scored.first.score!, scored.last.score!),
        ),
        Text(
          ProgressStrings.trendGoal(progress.activity),
          style: text.bodySmall,
        ),
        const SizedBox(height: AppSpacing.md),
        Semantics(
          label: ProgressStrings.trendSemantics(scored),
          child: ExcludeSemantics(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final (index, week) in progress.trend.indexed)
                  Expanded(
                    child: _TrendBar(
                      week: week,
                      latest: index == progress.trend.length - 1,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TrendBar extends StatelessWidget {
  const _TrendBar({required this.week, required this.latest});

  final WeeklyProgress week;
  final bool latest;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final score = week.score;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      child: Column(
        children: [
          Text(
            score == null ? ProgressStrings.trendNoScore : '$score%',
            style: text.labelSmall,
          ),
          const SizedBox(height: AppSpacing.xs),
          // A zero score keeps a stub so the week still reads as practised.
          Container(
            height: score == null
                ? AppSpacing.xs
                : AppSpacing.xs +
                      (AppSizes.trendChart - AppSpacing.xs) * score / 100,
            color: score == null
                ? AppColors.hairline
                : latest
                ? AppColors.ink
                : AppColors.sunshine,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            formatShortDate(week.weekStart),
            style: text.labelSmall?.copyWith(color: AppColors.muted),
            maxLines: 1,
            overflow: TextOverflow.fade,
            softWrap: false,
          ),
        ],
      ),
    );
  }
}
