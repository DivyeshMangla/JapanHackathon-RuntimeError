import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/l10n.dart';
import '../../../shared/widgets/ink_card.dart';
import '../../../shared/widgets/page_list.dart';
import '../domain/education_topic.dart';

/// Educational support: app orientation, practice guidance, voice care and
/// the study summary.
class LearnScreen extends StatelessWidget {
  const LearnScreen({super.key});

  static const _icons = {
    EducationTopic.usingTheApp: LucideIcons.smartphone,
    EducationTopic.homePractice: LucideIcons.calendarCheck,
    EducationTopic.voiceCare: LucideIcons.heartPulse,
    EducationTopic.aboutStudy: LucideIcons.fileText,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.learnTitle)),
      body: PageList(
        children: [
          Text(l10n.learnIntro, style: text.bodyLarge),
          const SizedBox(height: AppSpacing.lg),
          InkCard(
            padding: const EdgeInsets.all(AppSpacing.lg),
            onTap: () => context.push(
              AppRoutes.patientLearnTopic(EducationTopic.homePractice),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: const BoxDecoration(
                    color: AppColors.lilac,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(LucideIcons.calendarCheck, size: 28),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  l10n.topicTitle(EducationTopic.homePractice),
                  style: text.headlineMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  l10n.topicSummary(EducationTopic.homePractice),
                  style: text.bodySmall,
                ),
                const SizedBox(height: AppSpacing.md),
                FilledButton.icon(
                  onPressed: () => context.push(
                    AppRoutes.patientLearnTopic(EducationTopic.homePractice),
                  ),
                  icon: const Icon(LucideIcons.arrowRight, size: 18),
                  label: Text(l10n.learnReadGuide),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          InkCard(
            child: Column(
              children: [
                for (final topic in EducationTopic.values.where(
                  (t) => t != EducationTopic.homePractice,
                ))
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    onTap: () =>
                        context.push(AppRoutes.patientLearnTopic(topic)),
                    leading: Icon(_icons[topic], size: 22),
                    title: Text(
                      l10n.topicTitle(topic),
                      style: text.titleMedium,
                    ),
                    subtitle: Text(
                      l10n.topicSummary(topic),
                      style: text.bodySmall,
                    ),
                    trailing: const Icon(
                      LucideIcons.chevronRight,
                      size: 18,
                      color: AppColors.muted,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
