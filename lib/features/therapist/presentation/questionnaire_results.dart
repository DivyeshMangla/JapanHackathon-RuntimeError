import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/formatting.dart';
import '../../../core/utils/l10n.dart';
import '../../../shared/widgets/ink_card.dart';
import '../../questionnaires/domain/questionnaire.dart';

/// The participant's usability score and structured feedback, including
/// their own words, as submitted at follow-up.
class QuestionnaireResults extends StatelessWidget {
  const QuestionnaireResults({super.key, required this.questionnaires});

  final QuestionnaireHistory questionnaires;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    final usability = questionnaires.usability.firstOrNull;
    final feedback = questionnaires.satisfaction.firstOrNull;
    if (usability == null && feedback == null) {
      return Text(
        l10n.followUpNotSubmitted,
        style: text.bodyMedium?.copyWith(color: AppColors.muted),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (usability != null)
          InkCard(
            child: Row(
              children: [
                const Icon(LucideIcons.gauge, size: 20, color: AppColors.seal),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(l10n.susScoreLabel, style: text.titleSmall),
                ),
                Text(
                  formatDecimal(usability.score, 1),
                  style: text.titleMedium,
                ),
              ],
            ),
          ),
        if (feedback != null) ...[
          const SizedBox(height: AppSpacing.sm),
          _FeedbackCard(feedback: feedback),
        ],
      ],
    );
  }
}

class _FeedbackCard extends StatelessWidget {
  const _FeedbackCard({required this.feedback});

  final SatisfactionResponse feedback;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    final comments = [
      (l10n.feedbackLikedLabel, feedback.likedMost),
      (l10n.feedbackDifficultLabel, feedback.difficulties),
      (l10n.feedbackSuggestLabel, feedback.suggestions),
    ].where((c) => c.$2.isNotEmpty);
    return InkCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(l10n.satisfactionLabel, style: text.titleSmall),
              ),
              Text(
                l10n.meanOutOfFive(formatDecimal(feedback.meanRating, 1)),
                style: text.titleMedium,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final item in SatisfactionItem.values)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      l10n.satisfactionStatement(item),
                      style: text.bodySmall,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text('${feedback.ratings[item]}', style: text.bodyMedium),
                ],
              ),
            ),
          for (final (label, comment) in comments) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(label, style: text.labelMedium),
            Text(comment, style: text.bodyMedium),
          ],
        ],
      ),
    );
  }
}
