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
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/ink_card.dart';
import '../../../shared/widgets/page_list.dart';
import '../../../shared/widgets/stat_tile.dart';
import '../../exercises/domain/patient_activity.dart';
import '../../exercises/presentation/controllers/exercise_controllers.dart';
import '../domain/participant_summary.dart';
import 'controllers/caseload_controllers.dart';
import 'participant_card.dart';
import 'participant_links_card.dart';
import 'voice_diary_list.dart';

class ParticipantDetailScreen extends ConsumerWidget {
  const ParticipantDetailScreen({super.key, required this.patientId});

  final String patientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final participant = ref.watch(caseloadParticipantProvider(patientId));
    return Scaffold(
      appBar: AppBar(),
      body: AsyncView(
        value: participant,
        data: (participant) => participant == null
            ? const ParticipantNotFound()
            : PageList(
                children: [
                  _ProfileHeader(participant: participant),
                  const SizedBox(height: AppSpacing.lg),
                  StatusCard(participant: participant),
                  const SizedBox(height: AppSpacing.md),
                  ParticipantLinksCard(patientId: participant.patient.id),
                  _VoiceDiarySection(patientId: participant.patient.id),
                  const SizedBox(height: AppSpacing.md),
                  _ParticipantStats(participant: participant),
                  const SizedBox(height: AppSpacing.md),
                  SecondaryButton(
                    label: context.l10n.adherenceOverTime,
                    icon: LucideIcons.chartColumn,
                    onPressed: () => context.go(
                      AppRoutes.therapistAdherence(participant.patient.id),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  _Assignments(participant: participant),
                ],
              ),
      ),
    );
  }
}

class _VoiceDiarySection extends ConsumerWidget {
  const _VoiceDiarySection({required this.patientId});

  final String patientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(voiceDiaryProvider(patientId)).value;
    if (entries == null || entries.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionLabel(context.l10n.voiceDiaryTitle),
          VoiceDiaryList(entries: entries),
        ],
      ),
    );
  }
}

class ParticipantNotFound extends StatelessWidget {
  const ParticipantNotFound({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return EmptyState(
      icon: LucideIcons.userX,
      title: l10n.participantNotFoundTitle,
      message: l10n.participantNotFoundBody,
      actionLabel: l10n.backToParticipants,
      onAction: () => context.go(AppRoutes.therapistParticipants),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.participant});

  final ParticipantSummary participant;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final patient = participant.patient;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(participant.code, style: AppTypography.participantCode),
        Text(patient.name, style: text.headlineLarge),
        const SizedBox(height: AppSpacing.xs),
        Text(patient.email, style: text.bodySmall),
        Text(
          context.l10n.enrolledOn(formatFullDate(patient.createdAt)),
          style: text.bodySmall,
        ),
        if (participant.lowAdherence) ...[
          const SizedBox(height: AppSpacing.sm),
          const LowAdherenceFlag(),
        ],
      ],
    );
  }
}

class _ParticipantStats extends StatelessWidget {
  const _ParticipantStats({required this.participant});

  final ParticipantSummary participant;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final patientId = participant.patient.id;
    final activity = participant.activity;
    final nextProbe = participant.probeDue.nextDue;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 7,
          child: StatTile(
            icon: LucideIcons.chartColumn,
            label: l10n.windowDays(recentDays),
            value: formatPercent(activity.recentRate),
            caption: l10n.lastActive(activity.lastCompletedAt),
            onTap: () => context.go(AppRoutes.therapistAdherence(patientId)),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          flex: 4,
          child: StatTile(
            icon: LucideIcons.mic,
            label: l10n.samplesTitle,
            value: '${participant.recordings.length}',
            caption: nextProbe == null
                ? l10n.probesComplete
                : l10n.nextProbeOn(formatShortDate(nextProbe)),
            onTap: () =>
                context.go(AppRoutes.therapistRecordingsFor(patientId)),
          ),
        ),
      ],
    );
  }
}

class _Assignments extends StatelessWidget {
  const _Assignments({required this.participant});

  final ParticipantSummary participant;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    final patientId = participant.patient.id;
    final breakdown = participant.activity.exerciseBreakdown;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionLabel(l10n.assignedExercises),
        if (breakdown.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Text(
              l10n.noAssignments,
              style: text.bodyMedium?.copyWith(color: AppColors.muted),
            ),
          ),
        for (final row in breakdown)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: _AssignmentRow(
              row: row,
              onTap: () => context.push(
                AppRoutes.therapistAssign(
                  patientId,
                  scheduleId: row.schedule.id,
                ),
              ),
            ),
          ),
        const SizedBox(height: AppSpacing.sm),
        SecondaryButton(
          label: l10n.assignExercise,
          icon: LucideIcons.plus,
          onPressed: () => context.push(AppRoutes.therapistAssign(patientId)),
        ),
      ],
    );
  }
}

class _AssignmentRow extends StatelessWidget {
  const _AssignmentRow({required this.row, required this.onTap});

  final ExerciseAdherence row;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    final schedule = row.schedule;
    return InkCard(
      onTap: onTap,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(row.exercise.title, style: text.titleMedium),
                Text(
                  l10n.assignmentSummary(
                    l10n.describeWeekdays(schedule.weekdays),
                    schedule.sessionsPerDay,
                    schedule.repetitions,
                  ),
                  style: text.bodySmall,
                ),
              ],
            ),
          ),
          const Icon(LucideIcons.pencil, size: 18, color: AppColors.wash),
        ],
      ),
    );
  }
}

/// The participant's status from the research doc's status matrix, with the
/// suggested action.
class StatusCard extends StatelessWidget {
  const StatusCard({super.key, required this.participant});

  final ParticipantSummary participant;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    final status = participant.status;
    return InkCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(LucideIcons.compass, size: 20, color: AppColors.seal),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.statusTitle, style: text.labelMedium),
                Text(l10n.statusLabel(status), style: text.titleMedium),
                Text(l10n.statusAction(status), style: text.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
