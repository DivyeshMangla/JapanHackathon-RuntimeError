import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/l10n.dart';
import '../../../shared/widgets/ink_card.dart';
import '../domain/study_tasks.dart';
import 'controllers/questionnaire_controllers.dart';

/// Questionnaires due today, shown on the patient's Home tab. Nothing is
/// shown while loading or when none are due.
class StudyTasksCard extends ConsumerWidget {
  const StudyTasksCard({super.key, required this.patientId});

  final String patientId;

  static String routeFor(StudyTask task) => switch (task.kind) {
    StudyTaskKind.baselineSelfReport ||
    StudyTaskKind.weeklySelfReport => AppRoutes.patientSelfReport(task.week),
    StudyTaskKind.usability => AppRoutes.patientUsability,
    StudyTaskKind.feedback => AppRoutes.patientFeedback,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    final tasks = ref.watch(studyTasksProvider(patientId));
    if (tasks case AsyncError(:final error)) {
      return Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        child: Text(
          error is AppFailure ? l10n.failureMessage(error) : l10n.errorMessage,
          style: text.bodySmall?.copyWith(color: AppColors.error),
        ),
      );
    }
    final due = tasks.value ?? const [];
    if (due.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: InkCard(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(LucideIcons.clipboardList, color: AppColors.seal),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(l10n.homeTasksTitle, style: text.titleMedium),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(l10n.homeTasksBody, style: text.bodySmall),
            const SizedBox(height: AppSpacing.sm),
            for (final task in due) _TaskRow(task: task),
          ],
        ),
      ),
    );
  }
}

class _TaskRow extends StatelessWidget {
  const _TaskRow({required this.task});

  final StudyTask task;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    return InkWell(
      onTap: () => context.push(StudyTasksCard.routeFor(task)),
      borderRadius: BorderRadius.circular(AppRadius.base),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppSizes.minTouchTarget),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.taskTitle(task), style: text.bodyLarge),
                    Text(l10n.taskDuration(task.kind), style: text.bodySmall),
                  ],
                ),
              ),
              const Icon(LucideIcons.chevronRight, color: AppColors.wash),
            ],
          ),
        ),
      ),
    );
  }
}
