import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';

/// A big, bright picture button for the child: one icon, one word, and a
/// tick once it is done for today.
class ChildTile extends StatelessWidget {
  const ChildTile({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.done = false,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String? subtitle;
  final bool done;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final radius = BorderRadius.circular(AppRadius.base);
    return Semantics(
      button: true,
      label: [title, ?subtitle].join(', '),
      excludeSemantics: true,
      child: Material(
        color: color,
        borderRadius: radius,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: AppSizes.childTile),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                children: [
                  Container(
                    width: AppSizes.childTileIcon,
                    height: AppSizes.childTileIcon,
                    decoration: const BoxDecoration(
                      color: AppColors.surface,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      done ? LucideIcons.check : icon,
                      size: AppSizes.childTileIcon / 2,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: text.headlineMedium),
                        if (subtitle != null) ...[
                          const SizedBox(height: AppSpacing.xs),
                          Text(subtitle!, style: text.bodyLarge),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
