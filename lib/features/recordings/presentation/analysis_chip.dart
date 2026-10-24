import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/l10n.dart';
import '../domain/recording.dart';
import 'controllers/recording_controllers.dart';

/// Shows a recording's analysis state with an icon and a label.
class AnalysisChip extends ConsumerWidget {
  const AnalysisChip({super.key, required this.recording});

  final Recording recording;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status =
        ref.watch(analysisStatusProvider(recording)).value ??
        recording.analysisStatus;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.base),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(LucideIcons.hourglass, size: 14, color: AppColors.wash),
          const SizedBox(width: AppSpacing.xs),
          Text(
            context.l10n.analysisLabel(status),
            style: AppTypography.caption.copyWith(color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}
