import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/l10n.dart';
import '../../../shared/widgets/ink_card.dart';

/// Links from the participant screen to records kept about their app use.
class ParticipantLinksCard extends StatelessWidget {
  const ParticipantLinksCard({super.key, required this.patientId});

  final String patientId;

  @override
  Widget build(BuildContext context) {
    return InkCard(
      child: InkWell(
        onTap: () => context.push(AppRoutes.therapistUsage(patientId)),
        borderRadius: BorderRadius.circular(AppRadius.base),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSizes.minTouchTarget),
          child: Row(
            children: [
              const Icon(LucideIcons.activity, size: 18, color: AppColors.seal),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  context.l10n.usageLogTitle,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
              const Icon(
                LucideIcons.chevronRight,
                size: 18,
                color: AppColors.wash,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
