import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatting.dart';
import '../../../core/utils/l10n.dart';
import '../../../shared/widgets/failure_feedback.dart';
import 'controllers/playback_controller.dart';

/// Play/pause control with elapsed and total time for one audio source.
class PlaybackButton extends ConsumerWidget {
  const PlaybackButton({
    super.key,
    required this.source,
    required this.durationSec,
  });

  final PlaybackSource source;
  final double durationSec;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playback = ref.watch(playbackProvider);
    final playing = playback.isPlaying(source);
    final elapsed = playback.positionOf(source).inMilliseconds / 1000;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton.outlined(
          tooltip: playing ? context.l10n.pause : context.l10n.play,
          style: IconButton.styleFrom(
            side: const BorderSide(color: AppColors.wash, width: 1.5),
          ),
          icon: Icon(
            playing ? LucideIcons.pause : LucideIcons.play,
            size: 18,
            color: AppColors.seal,
          ),
          onPressed: () => runWithFailureMessage(
            context,
            () => ref.read(playbackProvider.notifier).toggle(source),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          '${formatSeconds(elapsed)} / ${formatSeconds(durationSec)}',
          style: AppTypography.monoSmall.copyWith(color: AppColors.muted),
        ),
      ],
    );
  }
}
