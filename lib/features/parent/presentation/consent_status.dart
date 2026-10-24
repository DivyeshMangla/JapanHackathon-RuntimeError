import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/formatting.dart';
import '../../../core/utils/l10n.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/skeleton.dart';
import 'controllers/family_controllers.dart';

/// Whether the parent has signed consent for [childId], with the way to
/// sign it when they have not. Practice is not shared until they do.
class ConsentStatus extends ConsumerWidget {
  const ConsentStatus({super.key, required this.childId});

  final String childId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    final consent = ref.watch(childConsentProvider(childId));
    return consent.when(
      loading: () => const Skeleton(height: AppSizes.minTouchTarget),
      error: (error, _) => Text(
        l10n.parentConsentUnknown,
        style: text.bodySmall?.copyWith(color: AppColors.error),
      ),
      data: (signed) => signed != null
          ? Row(
              children: [
                const Icon(LucideIcons.circleCheck, color: AppColors.teal),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    l10n.parentConsentSigned(formatShortDate(signed.signedAt)),
                    style: text.bodyMedium,
                  ),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(LucideIcons.penLine, color: AppColors.ink),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        l10n.parentConsentNeeded,
                        style: text.bodyMedium,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                PrimaryButton(
                  label: l10n.parentSignConsent,
                  icon: LucideIcons.signature,
                  onPressed: () =>
                      context.push(AppRoutes.parentConsent(childId)),
                ),
              ],
            ),
    );
  }
}
