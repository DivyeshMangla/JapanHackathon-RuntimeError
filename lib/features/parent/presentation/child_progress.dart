import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/formatting.dart';
import '../../../core/utils/l10n.dart';
import '../../../shared/widgets/async_view.dart';
import '../../../shared/widgets/page_list.dart';
import '../../../shared/widgets/skeleton.dart';
import '../../exercises/domain/patient_activity.dart';
import '../../exercises/presentation/adherence_panel.dart';
import '../../exercises/presentation/controllers/exercise_controllers.dart';

class ChildProgress extends ConsumerWidget {
  const ChildProgress({super.key, required this.userId});
  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) => AsyncView(
    value: ref.watch(patientActivityProvider(userId)),
    loading: const Skeleton(height: 240),
    data: (activity) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ProgressSummary(activity: activity),
        const SizedBox(height: AppSpacing.lg),
        SectionLabel(context.l10n.profileHistory),
        AdherencePanel(days: activity.days),
      ],
    ),
  );
}

class _ProgressSummary extends StatelessWidget {
  const _ProgressSummary({required this.activity});
  final PatientActivity activity;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        gradient: AppColors.darkGradient,
        borderRadius: BorderRadius.circular(AppRadius.base),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final rate = _Metric(
            label: l10n.progressLast14,
            value: formatPercent(activity.recentRate),
            caption: l10n.progressRateCaption,
          );
          final streak = _Metric(
            label: l10n.progressStreak,
            value: '${activity.streak}',
            caption: l10n.progressDays,
          );
          if (constraints.maxWidth < 280 ||
              MediaQuery.textScalerOf(context).scale(1) > 1.3) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                rate,
                const SizedBox(height: AppSpacing.lg),
                streak,
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: rate),
              const SizedBox(width: AppSpacing.lg),
              Expanded(child: streak),
            ],
          );
        },
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    required this.caption,
  });
  final String label;
  final String value;
  final String caption;
  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: text.labelMedium?.copyWith(color: AppColors.surface),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          value,
          style: text.headlineLarge?.copyWith(color: AppColors.sunshine),
        ),
        Text(
          caption,
          style: text.bodySmall?.copyWith(color: AppColors.onDarkMuted),
        ),
      ],
    );
  }
}
