import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/formatting.dart';
import '../../../core/utils/l10n.dart';
import '../../../shared/widgets/async_view.dart';
import '../../../shared/widgets/entry_cascade.dart';
import '../../../shared/widgets/ink_card.dart';
import '../../../shared/widgets/page_list.dart';
import '../../../shared/widgets/seal_mark.dart';
import '../../../shared/widgets/stat_tile.dart';
import '../../auth/presentation/controllers/auth_controller.dart';
import '../../auth/presentation/sign_out_button.dart';
import '../../exercises/domain/adherence.dart';
import '../../exercises/domain/patient_activity.dart';
import '../../recordings/presentation/analysis_chip.dart';
import '../../recordings/presentation/recording_tile.dart';
import '../../settings/domain/study_settings.dart';
import '../../settings/presentation/controllers/study_settings_controller.dart';
import '../domain/participant_summary.dart';
import 'controllers/caseload_controllers.dart';
import 'participant_card.dart';

class TherapistDashboardScreen extends ConsumerWidget {
  const TherapistDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final caseload = ref.watch(caseloadProvider);
    return Scaffold(
      appBar: AppBar(actions: const [SignOutButton()]),
      body: AsyncView(
        value: caseload,
        data: (caseload) => PageList(
          children: [
            EntryCascade(
              children: [
                const _Greeting(),
                const SizedBox(height: AppSpacing.xl),
                _CaseloadStats(caseload: caseload),
                const SizedBox(height: AppSpacing.xl),
                _NeedsAttention(caseload: caseload),
                const SizedBox(height: AppSpacing.xl),
                const _LatestRecordings(),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Greeting extends ConsumerWidget {
  const _Greeting();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final therapist = ref.watch(currentUserProvider);
    final text = Theme.of(context).textTheme;
    final now = DateTime.now();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          formatLongDate(now).toUpperCase(),
          style: text.labelMedium?.copyWith(color: AppColors.seal),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          context.l10n.greeting(now, therapist.firstName),
          style: text.headlineLarge,
        ),
        const SizedBox(height: AppSpacing.md),
      ],
    );
  }
}

class _CaseloadStats extends StatelessWidget {
  const _CaseloadStats({required this.caseload});

  final List<ParticipantSummary> caseload;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final overall = Adherence.rate([
      for (final p in caseload) ...p.activity.recent,
    ]);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 4,
          child: StatTile(
            icon: LucideIcons.users,
            label: l10n.caseload,
            value: '${caseload.length}',
            caption: l10n.participantsCount(caseload.length),
            onTap: () => context.go(AppRoutes.therapistParticipants),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          flex: 7,
          child: StatTile(
            icon: LucideIcons.chartColumn,
            label: l10n.caseloadAdherence,
            value: formatPercent(overall),
            caption: l10n.prescribedSessionsWindow(recentDays),
          ),
        ),
      ],
    );
  }
}

class _NeedsAttention extends ConsumerWidget {
  const _NeedsAttention({required this.caseload});

  final List<ParticipantSummary> caseload;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final threshold =
        ref.watch(studySettingsProvider).value?.adherenceThreshold ??
        const StudySettings().adherenceThreshold;
    final flagged =
        [
          for (final p in caseload)
            if (p.lowAdherence) p,
        ]..sort(
          (a, b) => (a.activity.recentRate ?? 0).compareTo(
            b.activity.recentRate ?? 0,
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionLabel(l10n.needsAttention),
        if (flagged.isEmpty)
          const _AllOnTrack()
        else
          for (final p in flagged)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: ParticipantCard(
                participant: p,
                onTap: () =>
                    context.go(AppRoutes.therapistParticipant(p.patient.id)),
              ),
            ),
        Text(
          l10n.flagRule(formatPercent(threshold), recentDays),
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _AllOnTrack extends StatelessWidget {
  const _AllOnTrack();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: InkCard(
        child: Row(
          children: [
            const SealMark(size: 36, icon: LucideIcons.check),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                context.l10n.allOnTrack,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LatestRecordings extends ConsumerWidget {
  const _LatestRecordings();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final recordings = ref.watch(caseloadRecordingsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionLabel(l10n.latestRecordings),
        AsyncView(
          value: recordings,
          loading: const SizedBox.shrink(),
          data: (list) => list.isEmpty
              ? Text(
                  l10n.noRecordingsYet,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: AppColors.muted),
                )
              : Column(
                  children: [
                    for (final (participant, recording) in list.take(3))
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: RecordingTile(
                          recording: recording,
                          participantCode: participant.code,
                          trailing: AnalysisChip(recording: recording),
                        ),
                      ),
                  ],
                ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => context.go(AppRoutes.therapistRecordings),
            icon: const Icon(LucideIcons.arrowRight, size: 18),
            label: Text(l10n.allVoiceSamples),
          ),
        ),
      ],
    );
  }
}
