import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../shared/widgets/action_page.dart';
import '../../../shared/widgets/buttons.dart';
import 'word_audio_controller.dart';
import 'word_strings.dart';

class WordCapturePanel extends StatelessWidget {
  const WordCapturePanel({super.key, required this.audio, this.enabled = true});
  final WordAudioController audio;
  final bool enabled;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: audio,
    builder: (context, _) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (audio.recording)
          Semantics(
            liveRegion: true,
            child: const InfoNotice(
              WordStrings.recording,
              icon: LucideIcons.mic,
            ),
          ),
        if (audio.message != null) InfoNotice(audio.message!),
        PrimaryButton(
          label: audio.recording
              ? WordStrings.stopRecording
              : audio.audio == null
              ? WordStrings.record
              : WordStrings.again,
          icon: audio.recording ? LucideIcons.square : LucideIcons.mic,
          onPressed: !enabled || audio.busy
              ? null
              : () => unawaited(audio.recording ? audio.stop() : audio.start()),
        ),
        if (audio.audio != null && !audio.recording) ...[
          const SizedBox(height: AppSpacing.sm),
          SecondaryButton(
            label: WordStrings.replay,
            icon: LucideIcons.play,
            onPressed: audio.busy
                ? null
                : () => unawaited(audio.play(audio.audio!)),
          ),
          const SizedBox(height: AppSpacing.sm),
          SecondaryButton(
            label: WordStrings.delete,
            icon: LucideIcons.trash2,
            onPressed: enabled && !audio.busy
                ? () => unawaited(audio.clear())
                : null,
          ),
        ],
        const SizedBox(height: AppSpacing.sm),
        SecondaryButton(
          label: WordStrings.stopPlayback,
          icon: LucideIcons.square,
          onPressed: () => unawaited(audio.stopPlayback()),
        ),
      ],
    ),
  );
}
