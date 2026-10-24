import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import 'child_activity_picture.dart';

class ChildPracticeIntro extends StatelessWidget {
  const ChildPracticeIntro({
    super.key,
    required this.activity,
    required this.message,
    required this.color,
  });

  final ChildActivity activity;
  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpacing.md),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(AppRadius.base),
    ),
    child: Row(
      children: [
        Container(
          width: AppSizes.childTileIcon,
          height: AppSizes.childTileIcon,
          decoration: const BoxDecoration(
            color: AppColors.surface,
            shape: BoxShape.circle,
          ),
          child: ChildActivityPicture(activity: activity),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Text(message, style: Theme.of(context).textTheme.bodyLarge),
        ),
      ],
    ),
  );
}
