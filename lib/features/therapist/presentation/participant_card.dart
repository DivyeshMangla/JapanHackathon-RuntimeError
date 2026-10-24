import 'package:flutter/material.dart';

import '../../../core/theme/app_typography.dart';
import '../../../core/utils/l10n.dart';
import '../../../shared/widgets/ink_card.dart';
import '../domain/participant_summary.dart';

/// A caseload entry: participant code, name and parent.
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
    final parentName = participant.patient.parentName;
    return InkCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(participant.code, style: AppTypography.participantCode),
          Text(participant.patient.name, style: text.titleMedium),
          if (parentName != null)
            Text(l10n.participantParent(parentName), style: text.bodySmall),
        ],
      ),
    );
  }
}
