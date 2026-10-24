import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatting.dart';
import '../../../core/utils/l10n.dart';
import '../../../shared/widgets/ink_card.dart';
import '../../capture_quality/domain/take_quality.dart';

/// Says whether the take under review is fit for analysis and, if not,
/// what to change before recording again.
class TakeQualityCard extends StatelessWidget {
  const TakeQualityCard({
    super.key,
    required this.quality,
    required this.checking,
  });

  final TakeQuality? quality;
  final bool checking;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    final quality = this.quality;
    if (checking) {
      return Semantics(
        liveRegion: true,
        child: Text(
          l10n.takeQualityChecking,
          style: text.bodySmall?.copyWith(color: AppColors.muted),
        ),
      );
    }
    if (quality == null) return const SizedBox.shrink();

    final rating = quality.rating;
    final (icon, color, title, body) = switch (rating) {
      TakeRating.good => (
        LucideIcons.circleCheck,
        AppColors.ink,
        l10n.takeQualityGood,
        l10n.takeQualityGoodBody,
      ),
      TakeRating.acceptable => (
        LucideIcons.circleCheck,
        AppColors.ink,
        l10n.takeQualityAcceptable,
        l10n.takeQualityAcceptableBody,
      ),
      TakeRating.poor => (
        LucideIcons.circleAlert,
        AppColors.error,
        l10n.takeQualityPoor,
        l10n.takeQualityPoorBody,
      ),
    };

    return Semantics(
      liveRegion: true,
      child: InkCard(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: text.titleMedium?.copyWith(color: color)),
                  const SizedBox(height: AppSpacing.xs),
                  Text(body, style: text.bodySmall),
                  for (final issue in quality.issues) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(l10n.takeIssueText(issue), style: text.bodyMedium),
                  ],
                  if (quality.snrDb case final snr?) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      l10n.takeQualitySnr(formatDecimal(snr, 0)),
                      style: AppTypography.monoSmall.copyWith(
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
