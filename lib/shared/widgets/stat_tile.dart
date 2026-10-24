import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import 'ink_card.dart';

/// A single headline figure with a label above and a caption below.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    this.caption,
    this.icon,
    this.onTap,
  });

  final String label;
  final String value;
  final String? caption;
  final IconData? icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return InkCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: AppColors.seal),
                const SizedBox(width: AppSpacing.sm),
              ],
              Expanded(child: Text(label, style: text.labelMedium)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(value, style: text.headlineMedium),
          if (caption != null)
            Text(caption!, style: text.bodySmall, maxLines: 2),
        ],
      ),
    );
  }
}
