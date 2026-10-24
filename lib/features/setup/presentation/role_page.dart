import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/setup_state.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../shared/widgets/action_page.dart';
import '../../../shared/widgets/ink_card.dart';
import '../../../shared/widgets/seal_mark.dart';
import 'setup_actions.dart';

class RolePage extends ConsumerStatefulWidget {
  const RolePage({super.key});

  @override
  ConsumerState<RolePage> createState() => _RolePageState();
}

class _RolePageState extends ConsumerState<RolePage> with SetupActions {
  @override
  Widget build(BuildContext context) {
    return ActionPage(
      title: s('unset'),
      intro: s('roleIntro'),
      error: error,
      children: [
        for (final role in DeviceRole.values)
          _RoleCard(
            icon: role == DeviceRole.patient
                ? LucideIcons.userRound
                : LucideIcons.stethoscope,
            title: label(role.name),
            hint: s('${role.name}RoleHint'),
            onTap: action(role.name, () => service.chooseRole(role)),
          ),
      ],
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.icon,
    required this.title,
    required this.hint,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String hint;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      enabled: onTap != null,
      child: InkCard(
        onTap: onTap,
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            SealMark(icon: icon),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: text.titleLarge),
                  const SizedBox(height: AppSpacing.xs),
                  Text(hint, style: text.bodySmall),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            const Icon(
              LucideIcons.chevronRight,
              size: 20,
              color: AppColors.wash,
            ),
          ],
        ),
      ),
    );
  }
}
