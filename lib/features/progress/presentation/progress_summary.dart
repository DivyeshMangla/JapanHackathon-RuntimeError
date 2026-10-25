import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/formatting.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/ink_card.dart';
import '../../../shared/widgets/page_list.dart';
import '../domain/family_progress.dart';
import 'progress_strings.dart';
import 'progress_trend.dart';

class ProgressSummary extends StatelessWidget {
  const ProgressSummary({
    super.key,
    required this.progress,
    this.showTrend = false,
  });

  final FamilyProgress progress;
  final bool showTrend;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SectionLabel(ProgressStrings.participation),
      Text(ProgressStrings.participationHelp),
      const SizedBox(height: AppSpacing.md),
      if (!progress.hasPractice)
        const EmptyState(
          icon: LucideIcons.chartNoAxesCombined,
          title: ProgressStrings.noPracticeTitle,
          message: ProgressStrings.noPracticeBody,
        ),
      for (final activity in progress.activities) ...[
        _ActivityProgressCard(progress: activity, showTrend: showTrend),
        const SizedBox(height: AppSpacing.md),
      ],
    ],
  );
}

class _ActivityProgressCard extends StatelessWidget {
  const _ActivityProgressCard({
    required this.progress,
    required this.showTrend,
  });

  final ActivityProgress progress;
  final bool showTrend;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final lastPractice = progress.lastPracticedAt;
    final hasAssessment =
        progress.clinicianCorrect +
            progress.clinicianOnTrack +
            progress.clinicianNeedsPractice >
        0;
    return InkCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            ProgressStrings.activity(progress.activity),
            style: text.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(ProgressStrings.counts(progress)),
          if (lastPractice != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              ProgressStrings.practiced(formatFullDate(lastPractice)),
              style: text.bodySmall,
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          if (progress.activity != ProgressActivity.expressions)
            Text(
              hasAssessment
                  ? ProgressStrings.assessmentCounts(progress)
                  : ProgressStrings.noAssessment,
            ),
          if (progress.quizTotal > 0) ...[
            Text(ProgressStrings.quizCounts(progress)),
            if (progress.quizIndependentTotal > 0)
              Text(ProgressStrings.independentChoices(progress)),
            if (progress.quizAssistedTotal > 0)
              Text(ProgressStrings.assistedChoices(progress)),
            const SizedBox(height: AppSpacing.xs),
            Text(ProgressStrings.quizHelp, style: text.bodySmall),
          ],
          if (showTrend && progress.trend.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            ProgressTrend(progress: progress),
          ],
        ],
      ),
    );
  }
}
