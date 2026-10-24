import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/formatting.dart';
import '../../../core/utils/l10n.dart';
import '../../../shared/widgets/ink_card.dart';
import '../../exercises/domain/voice_use_entry.dart';

/// A participant's voice-use monitoring entries, newest first.
class VoiceDiaryList extends StatelessWidget {
  const VoiceDiaryList({super.key, required this.entries});

  final List<VoiceUseEntry> entries;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final entry in entries.reversed)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: InkCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(formatDayMonth(entry.day), style: text.titleSmall),
                  Text(
                    l10n.voiceDiarySummary(
                      l10n.speakingTimeLabel(entry.speakingTime),
                      entry.fatigue,
                    ),
                    style: text.bodyMedium,
                  ),
                  if (entry.situations.isNotEmpty)
                    Text(
                      [
                        for (final s in VoiceSituation.values)
                          if (entry.situations.contains(s))
                            l10n.situationLabel(s),
                      ].join(', '),
                      style: text.bodySmall,
                    ),
                  if (entry.note.isNotEmpty)
                    Text(entry.note, style: text.bodySmall),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
