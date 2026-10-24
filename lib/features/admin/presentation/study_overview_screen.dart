import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatting.dart';
import '../../../core/utils/l10n.dart';
import '../../../shared/widgets/async_view.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/ink_card.dart';
import '../../../shared/widgets/page_list.dart';
import '../../../shared/widgets/stat_tile.dart';
import '../../auth/presentation/sign_out_button.dart';
import '../../exercises/domain/patient_activity.dart';
import '../../settings/presentation/controllers/study_settings_controller.dart';
import '../../study/domain/participant_status.dart';
import '../../therapist/domain/participant_summary.dart';
import '../domain/study_overview.dart';
import 'controllers/admin_controllers.dart';

class StudyOverviewScreen extends ConsumerWidget {
  const StudyOverviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final overview = ref.watch(studyOverviewProvider);
    final participants = ref.watch(studyParticipantsProvider).value ?? const [];
    final threshold = ref
        .watch(studySettingsProvider)
        .value
        ?.adherenceThreshold;
    final thresholdLabel = formatPercent(threshold);

    return Scaffold(
      appBar: AppBar(actions: const [SignOutButton()]),
      body: AsyncView(
        value: overview,
        data: (overview) => PageList(
          children: [
            const _OverviewHeader(),
            const SizedBox(height: AppSpacing.xl),
            _HeadlineStats(overview: overview, thresholdLabel: thresholdLabel),
            const SizedBox(height: AppSpacing.md),
            const _OutcomesLink(),
            const SizedBox(height: AppSpacing.xl),
            SectionLabel(l10n.statusMatrix),
            _StatusMatrix(counts: overview.statusCounts),
            const SizedBox(height: AppSpacing.sm),
            Text(
              l10n.statusMatrixNote(thresholdLabel),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.xl),
            SectionLabel(l10n.participantsSection),
            if (participants.isEmpty)
              EmptyState(
                icon: LucideIcons.userPlus,
                title: l10n.noEnrolledTitle,
                message: l10n.noEnrolledBody,
              ),
            for (final p in participants)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _ParticipantRow(participant: p),
              ),
          ],
        ),
      ),
    );
  }
}

class _OverviewHeader extends StatelessWidget {
  const _OverviewHeader();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.studyOverviewEyebrow.toUpperCase(),
          style: text.labelMedium?.copyWith(color: AppColors.seal),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(l10n.studyName, style: text.headlineLarge),
        const SizedBox(height: AppSpacing.md),
      ],
    );
  }
}

class _HeadlineStats extends StatelessWidget {
  const _HeadlineStats({required this.overview, required this.thresholdLabel});

  final StudyOverview overview;
  final String thresholdLabel;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 4,
          child: StatTile(
            icon: LucideIcons.userPlus,
            label: l10n.enrolled,
            value: '${overview.enrolled}',
            caption: l10n.therapistCount(overview.therapists),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          flex: 7,
          child: StatTile(
            icon: LucideIcons.chartColumn,
            label: l10n.overallAdherence,
            value: formatPercent(overview.overallAdherence),
            caption: l10n.overallAdherenceCaption(
              recentDays,
              overview.lowAdherence,
              thresholdLabel,
            ),
          ),
        ),
      ],
    );
  }
}

/// Feasibility headline and the way into the full outcome measures.
class _OutcomesLink extends ConsumerWidget {
  const _OutcomesLink();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    final outcomes = ref.watch(studyOutcomesProvider).value;
    return InkCard(
      onTap: () => context.go(AppRoutes.adminOutcomes),
      child: Row(
        children: [
          const Icon(LucideIcons.chartNoAxesCombined, color: AppColors.seal),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.outcomesTitle, style: text.titleMedium),
                Text(
                  outcomes == null
                      ? l10n.outcomesLinkBody
                      : l10n.outcomesLinkSummary(
                          formatPercent(outcomes.retention.rate),
                          formatPercent(outcomes.usageCompletion.rate),
                        ),
                  style: text.bodySmall,
                ),
              ],
            ),
          ),
          const Icon(LucideIcons.chevronRight, color: AppColors.wash),
        ],
      ),
    );
  }
}

class _StatusMatrix extends StatelessWidget {
  const _StatusMatrix({required this.counts});

  final Map<ParticipantStatus, int> counts;

  @override
  Widget build(BuildContext context) {
    return InkCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Column(
        children: [
          for (final status in ParticipantStatus.values)
            _StatusRow(status: status, count: counts[status] ?? 0),
        ],
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.status, required this.count});

  final ParticipantStatus status;
  final int count;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.statusLabel(status), style: text.titleSmall),
                Text(l10n.statusAction(status), style: text.bodySmall),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Text(
            '$count',
            style: AppTypography.monoLarge.copyWith(
              color: count == 0 ? AppColors.muted : AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}

class _ParticipantRow extends StatelessWidget {
  const _ParticipantRow({required this.participant});

  final ParticipantSummary participant;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    return InkCard(
      child: Row(
        children: [
          SizedBox(
            width: AppSizes.valueColumn,
            child: Text(participant.code, style: AppTypography.participantCode),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.statusLabel(participant.status),
                  style: text.titleSmall,
                ),
                if (participant.lowAdherence)
                  Text(l10n.lowAdherence, style: text.bodySmall),
              ],
            ),
          ),
          Text(
            formatPercent(participant.activity.recentRate),
            style: text.titleMedium,
          ),
        ],
      ),
    );
  }
}
