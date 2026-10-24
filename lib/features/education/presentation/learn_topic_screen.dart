import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/l10n.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/page_list.dart';
import '../../usage/domain/usage_event.dart';
import '../../usage/presentation/usage_tracker.dart';
import '../domain/education_topic.dart';

class LearnTopicScreen extends StatelessWidget {
  const LearnTopicScreen({super.key, required this.topicName});

  /// The topic's enum name from the URL.
  final String topicName;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final topic = EducationTopic.values
        .where((t) => t.name == topicName)
        .firstOrNull;
    if (topic == null) {
      return Scaffold(
        appBar: AppBar(),
        body: EmptyState(
          icon: LucideIcons.fileQuestion,
          title: l10n.learnNotFoundTitle,
          message: l10n.learnNotFoundBody,
        ),
      );
    }
    final text = Theme.of(context).textTheme;
    final note = l10n.topicNote(topic);
    return UsageTracker(
      action: UsageAction.educationOpened,
      detail: topic.name,
      child: Scaffold(
        appBar: AppBar(title: Text(l10n.topicTitle(topic))),
        body: PageList(
          children: [
            Text(l10n.topicSummary(topic), style: text.bodyLarge),
            const SizedBox(height: AppSpacing.lg),
            for (final (index, point) in l10n.topicPoints(topic).indexed)
              _Point(number: index + 1, text: point),
            if (note != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                note,
                style: text.bodyMedium?.copyWith(color: AppColors.muted),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Point extends StatelessWidget {
  const _Point({required this.number, required this.text});

  final int number;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: AppSizes.counterColumn,
            child: Text(
              number.toString().padLeft(2, '0'),
              style: AppTypography.mono.copyWith(color: AppColors.seal),
            ),
          ),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodyLarge),
          ),
        ],
      ),
    );
  }
}
