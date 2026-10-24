import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/l10n.dart';
import '../../../shared/widgets/entry_cascade.dart';
import '../../../shared/widgets/ink_card.dart';
import '../../../shared/widgets/melo_mark.dart';
import '../../../shared/widgets/page_list.dart';
import 'demo_sign_in_panel.dart';

/// The first page on a phone nobody is signed in to: whoever holds it picks
/// how they use Melo, and each choice leads to its own way in.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: PageList(
          children: [
            EntryCascade(
              children: [
                const SizedBox(height: AppSpacing.lg),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: MeloMark(size: AppSizes.welcomeMark),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(l10n.appTitle, style: text.displayLarge),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  l10n.welcomeTagline,
                  style: text.bodyLarge?.copyWith(color: AppColors.muted),
                ),
                const SizedBox(height: AppSpacing.xl),
                SectionLabel(l10n.welcomeQuestion),
                _WelcomeChoice(
                  icon: LucideIcons.heartHandshake,
                  color: AppColors.sunshine,
                  title: l10n.welcomeParent,
                  description: l10n.welcomeParentHint,
                  onTap: () => context.push(AppRoutes.parentSignUp),
                ),
                const SizedBox(height: AppSpacing.md),
                _WelcomeChoice(
                  icon: LucideIcons.stethoscope,
                  color: AppColors.orchid,
                  title: l10n.welcomeTherapist,
                  description: l10n.welcomeTherapistHint,
                  onTap: () => context.push(AppRoutes.login),
                ),
                // Developer tools; release builds never show them.
                if (!kReleaseMode) ...[
                  const SizedBox(height: AppSpacing.xl),
                  const DemoSignInPanel(),
                  const SizedBox(height: AppSpacing.md),
                  Center(
                    child: TextButton.icon(
                      onPressed: () => context.push(AppRoutes.sensorCheck),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.muted,
                      ),
                      icon: const Icon(LucideIcons.activity),
                      label: Text(l10n.sensorCheckOpen),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _WelcomeChoice extends StatelessWidget {
  const _WelcomeChoice({
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      label: title,
      hint: description,
      excludeSemantics: true,
      child: InkCard(
        onTap: onTap,
        child: Row(
          children: [
            Container(
              width: AppSizes.choiceIcon,
              height: AppSizes.choiceIcon,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              child: Icon(icon, color: AppColors.ink),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: text.titleLarge),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    description,
                    style: text.bodyMedium?.copyWith(color: AppColors.muted),
                  ),
                ],
              ),
            ),
            const Icon(LucideIcons.chevronRight, color: AppColors.wash),
          ],
        ),
      ),
    );
  }
}
