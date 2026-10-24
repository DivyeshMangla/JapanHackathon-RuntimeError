import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatting.dart';
import '../../../core/utils/l10n.dart';
import '../../../shared/widgets/ink_card.dart';
import '../../exercises/domain/patient_activity.dart';
import '../domain/participant_summary.dart';

/// A caseload entry: code, name, recent adherence and last activity, with a
/// labelled flag when adherence is low.
class ParticipantCard extends StatelessWidget {
  const ParticipantCard({
    super.key,
    required this.participant,
    required this.onTap,
  });

  final ParticipantSummary participant;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final l10n = context.l10n;
    final activity = participant.activity;
    final rate = activity.recentRate;

    return InkCard(
      onTap: onTap,
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
                    Text(
                      participant.code,
                      style: AppTypography.participantCode,
                    ),
                    Text(participant.patient.name, style: text.titleMedium),
                    Text(
                      l10n.lastActive(activity.lastCompletedAt),
                      style: text.bodySmall,
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(formatPercent(rate), style: text.headlineSmall),
                  Text(l10n.windowDays(recentDays), style: text.bodySmall),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.base),
            child: LinearProgressIndicator(
              value: rate ?? 0,
              minHeight: AppSizes.progressThin,
            ),
          ),
          if (participant.lowAdherence) ...[
            const SizedBox(height: AppSpacing.sm),
            const LowAdherenceFlag(),
          ],
        ],
      ),
    );
  }
}

class LowAdherenceFlag extends StatelessWidget {
  const LowAdherenceFlag({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(LucideIcons.flag, size: 14, color: AppColors.seal),
        const SizedBox(width: AppSpacing.xs),
        Text(
          context.l10n.lowAdherence,
          style: AppTypography.caption.copyWith(
            color: AppColors.seal,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
