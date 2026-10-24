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
import '../../../shared/widgets/link_code_card.dart';
import '../../../shared/widgets/page_list.dart';
import '../../../shared/widgets/stat_tile.dart';
import '../../auth/presentation/controllers/auth_controller.dart';
import '../../auth/presentation/sign_out_button.dart';
import '../../recordings/presentation/analysis_chip.dart';
import '../../recordings/presentation/recording_tile.dart';
import '../domain/participant_summary.dart';
import 'controllers/caseload_controllers.dart';

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
                const _TherapistCode(),
                const SizedBox(height: AppSpacing.xl),
                _CaseloadStats(caseload: caseload),
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

/// The code parents enter at sign-up to join this caseload.
class _TherapistCode extends ConsumerWidget {
  const _TherapistCode();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final code = ref.watch(currentUserProvider).linkCode;
    if (code == null) return const SizedBox.shrink();
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: LinkCodeCard(
        title: l10n.therapistCodeTitle,
        code: code,
        message: l10n.therapistCodeHowTo,
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
    final samples = caseload.fold(0, (sum, p) => sum + p.recordings.length);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 5,
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
          flex: 6,
          child: StatTile(
            icon: LucideIcons.audioLines,
            label: l10n.navVoiceSamples,
            value: '$samples',
            onTap: () => context.go(AppRoutes.therapistRecordings),
          ),
        ),
      ],
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
