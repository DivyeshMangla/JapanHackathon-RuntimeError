import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatting.dart';
import '../../../core/utils/l10n.dart';
import '../../../shared/widgets/async_view.dart';
import '../../../shared/widgets/ink_card.dart';
import '../../../shared/widgets/page_list.dart';
import '../../../shared/widgets/stat_tile.dart';
import '../../exercises/domain/adherence.dart';
import '../../exercises/domain/patient_activity.dart';
import '../../exercises/presentation/adherence_panel.dart';
import 'controllers/caseload_controllers.dart';
import 'participant_detail_screen.dart';

class ParticipantAdherenceScreen extends ConsumerWidget {
  const ParticipantAdherenceScreen({super.key, required this.patientId});

  final String patientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final participant = ref.watch(caseloadParticipantProvider(patientId));
    final text = Theme.of(context).textTheme;
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.adherenceTitle)),
      body: AsyncView(
        value: participant,
        data: (participant) {
          if (participant == null) return const ParticipantNotFound();
          final activity = participant.activity;
          return PageList(
            children: [
              Text(participant.code, style: AppTypography.participantCode),
              Text(participant.patient.name, style: text.headlineMedium),
              const SizedBox(height: AppSpacing.lg),
              _WindowRates(activity: activity),
              const SizedBox(height: AppSpacing.lg),
              AdherencePanel(days: activity.days),
              const SizedBox(height: AppSpacing.lg),
              StatusCard(participant: participant),
              const SizedBox(height: AppSpacing.lg),
              SectionLabel(l10n.byExerciseWindow(recentDays)),
              for (final row in activity.exerciseBreakdown)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: _ExerciseRow(row: row),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _WindowRates extends StatelessWidget {
  const _WindowRates({required this.activity});

  final PatientActivity activity;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 6,
          child: StatTile(
            icon: LucideIcons.chartColumn,
            label: l10n.windowDays(recentDays),
            value: formatPercent(activity.recentRate),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          flex: 5,
          child: StatTile(
            icon: LucideIcons.calendarDays,
            label: l10n.last7Days,
            value: formatPercent(Adherence.rate(lastPeriods(activity.days, 7))),
          ),
        ),
      ],
    );
  }
}

class _ExerciseRow extends StatelessWidget {
  const _ExerciseRow({required this.row});

  final ExerciseAdherence row;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final l10n = context.l10n;
    return InkCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(row.exercise.title, style: text.titleMedium),
                    Text(
                      l10n.exerciseSessions(
                        l10n.describeWeekdays(row.schedule.weekdays),
                        row.done,
                        row.due,
                      ),
                      style: text.bodySmall,
                    ),
                  ],
                ),
              ),
              Text(formatPercent(row.rate), style: text.titleMedium),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.base),
            child: LinearProgressIndicator(
              value: row.rate ?? 0,
              minHeight: AppSizes.progressThin,
            ),
          ),
        ],
      ),
    );
  }
}
