import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatting.dart';
import '../../../core/utils/l10n.dart';
import '../../../shared/widgets/ink_card.dart';
import '../domain/recording.dart';
import 'controllers/playback_controller.dart';
import 'playback_button.dart';

/// One saved recording with its metadata and a play control. [trailing]
/// lets other roles add extra status, such as analysis state.
class RecordingTile extends StatelessWidget {
  const RecordingTile({
    super.key,
    required this.recording,
    this.participantCode,
    this.trailing,
  });

  final Recording recording;

  /// Shown above the task when listing several patients' recordings.
  final String? participantCode;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final l10n = context.l10n;
    final task = l10n.taskLabel(recording.task);
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
                    if (participantCode != null)
                      Text(
                        participantCode!,
                        style: AppTypography.participantCode,
                      ),
                    Text(
                      recording.kind == RecordingKind.probe
                          ? l10n.recordingTake(task, recording.trial)
                          : task,
                      style: text.titleMedium,
                    ),
                    Text(
                      '${l10n.kindLabel(recording.kind)}  ·  '
                      '${l10n.typeLabel(recording.type)}  ·  '
                      '${formatDateTime(recording.createdAt)}',
                      style: text.bodySmall,
                    ),
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          PlaybackButton(
            source: PlaybackSource.recording(recording, label: participantCode),
            durationSec: recording.durationSec,
          ),
        ],
      ),
    );
  }
}
