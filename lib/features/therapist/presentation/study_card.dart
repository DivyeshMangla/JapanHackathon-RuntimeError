import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/formatting.dart';
import '../../../core/utils/l10n.dart';
import '../../../shared/widgets/ink_card.dart';
import '../../../shared/widgets/skeleton.dart';
import '../domain/participant_study.dart';
import 'assessment_widgets.dart';
import 'controllers/caseload_controllers.dart';

/// Study progress on the participant screen: phase, intervention adherence
/// and compliance, assessment completeness, and links to the study forms.
class StudyCard extends ConsumerWidget {
  const StudyCard({super.key, required this.patientId});

  final String patientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return switch (ref.watch(participantStudyProvider(patientId))) {
      AsyncData(value: final study?) => _StudyCardBody(study: study),
      AsyncError(:final error) => Text(
        error is AppFailure ? l10n.failureMessage(error) : l10n.errorMessage,
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: AppColors.error),
      ),
      AsyncData() => const SizedBox.shrink(),
      _ => const Skeleton(height: 160),
    };
  }
}

class _StudyCardBody extends StatelessWidget {
  const _StudyCardBody({required this.study});

  final ParticipantStudy study;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    final patientId = study.summary.patient.id;
    final outcome = study.outcome;
    final baselineDone = study.baseline.values.where((v) => v).length;
    final followUpDone = study.followUp.values.where((v) => v).length;
    return InkCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.studySection, style: text.labelMedium),
          StudyPhaseText(record: study.record, period: outcome.period),
          const SizedBox(height: AppSpacing.sm),
          Text(
            l10n.studyRates(
              formatPercent(outcome.adherence),
              formatPercent(outcome.compliance),
            ),
            style: text.titleMedium,
          ),
          Text(
            l10n.assessmentProgress(
              baselineDone,
              study.baseline.length,
              followUpDone,
              study.followUp.length,
            ),
            style: text.bodySmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          _LinkRow(
            icon: LucideIcons.clipboardList,
            label: l10n.assessmentTitle,
            onTap: () => context.push(AppRoutes.therapistAssessment(patientId)),
          ),
          _LinkRow(
            icon: LucideIcons.clipboardPen,
            label: l10n.studyRecordTitle,
            onTap: () =>
                context.push(AppRoutes.therapistStudyRecord(patientId)),
          ),
          _LinkRow(
            icon: LucideIcons.activity,
            label: l10n.usageLogTitle,
            onTap: () => context.push(AppRoutes.therapistUsage(patientId)),
          ),
        ],
      ),
    );
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.base),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppSizes.minTouchTarget),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppColors.seal),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(label, style: Theme.of(context).textTheme.bodyLarge),
            ),
            const Icon(
              LucideIcons.chevronRight,
              size: 18,
              color: AppColors.wash,
            ),
          ],
        ),
      ),
    );
  }
}
