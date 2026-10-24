import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/l10n.dart';
import '../../../shared/widgets/ink_card.dart';

/// An exercise's safety note, labelled in words and marked with an icon so
/// the meaning never rests on colour alone.
class CautionNote extends StatelessWidget {
  const CautionNote({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return InkCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            LucideIcons.triangleAlert,
            size: 20,
            color: AppColors.seal,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.l10n.cautionTitle, style: theme.titleSmall),
                Text(text, style: theme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
