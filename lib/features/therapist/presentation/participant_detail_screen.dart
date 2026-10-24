import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatting.dart';
import '../../../core/utils/l10n.dart';
import '../../../shared/widgets/async_view.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/page_list.dart';
import '../../../shared/widgets/stat_tile.dart';
import '../domain/participant_summary.dart';
import 'controllers/caseload_controllers.dart';
import 'participant_links_card.dart';

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
                  ParticipantLinksCard(patientId: participant.patient.id),
                  const SizedBox(height: AppSpacing.md),
                  _SamplesTile(participant: participant),
                ],
              ),
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
      ],
    );
  }
}

class _SamplesTile extends StatelessWidget {
  const _SamplesTile({required this.participant});

  final ParticipantSummary participant;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final patientId = participant.patient.id;
    final nextProbe = participant.probeDue.nextDue;
    return StatTile(
      icon: LucideIcons.mic,
      label: l10n.samplesTitle,
      value: '${participant.recordings.length}',
      caption: nextProbe == null
          ? l10n.probesComplete
          : l10n.nextProbeOn(formatShortDate(nextProbe)),
      onTap: () => context.go(AppRoutes.therapistRecordingsFor(patientId)),
    );
  }
}
