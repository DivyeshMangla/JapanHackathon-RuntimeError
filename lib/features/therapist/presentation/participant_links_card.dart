import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/l10n.dart';
import '../../../shared/widgets/ink_card.dart';

/// Links from the participant screen to the child's practice activities
/// practice and to the record of their app use.
class ParticipantLinksCard extends StatelessWidget {
  const ParticipantLinksCard({super.key, required this.patientId});

  final String patientId;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return InkCard(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Column(
        children: [
          _Link(
            icon: LucideIcons.messageCircle,
            label: l10n.therapistWordsLink,
            onTap: () => context.push(AppRoutes.therapistWords(patientId)),
          ),
          _Link(
            icon: LucideIcons.pencil,
            label: l10n.therapistDrawingLink,
            onTap: () => context.push(AppRoutes.therapistDrawing(patientId)),
          ),
          _Link(
            icon: LucideIcons.smile,
            label: l10n.therapistExpressionsLink,
            onTap: () =>
                context.push(AppRoutes.therapistExpressions(patientId)),
          ),
          _Link(
            icon: LucideIcons.activity,
            label: l10n.usageLogTitle,
            onTap: () => context.push(AppRoutes.therapistUsage(patientId)),
          ),
        ],
      ),
    );
  }
}

class _Link extends StatelessWidget {
  const _Link({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    minTileHeight: AppSizes.minTouchTarget,
    leading: Icon(icon, color: AppColors.seal),
    title: Text(label, style: Theme.of(context).textTheme.bodyLarge),
    trailing: const Icon(LucideIcons.chevronRight, color: AppColors.wash),
    onTap: onTap,
  );
}
