import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import '../theme/app_typography.dart';

/// Floating capsule navigation shared by all role areas.
class RoleShell extends StatelessWidget {
  const RoleShell({super.key, required this.shell, required this.destinations});

  final StatefulNavigationShell shell;
  final List<NavigationDestination> destinations;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: shell,
    bottomNavigationBar: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.sm,
        ),
        child: Align(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xs),
                child: Row(
                  children: [
                    for (var index = 0; index < destinations.length; index++)
                      Expanded(
                        flex: index == shell.currentIndex ? 2 : 1,
                        child: _Tab(
                          destination: destinations[index],
                          selected: index == shell.currentIndex,
                          onTap: () => shell.goBranch(
                            index,
                            initialLocation: index == shell.currentIndex,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.destination,
    required this.selected,
    required this.onTap,
  });
  final NavigationDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    label: destination.label,
    selected: selected,
    button: true,
    child: Tooltip(
      message: destination.label,
      excludeFromSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: selected ? AppColors.ink : null,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 56),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: AppSpacing.sm,
                    horizontal: AppSpacing.xs,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconTheme(
                        data: IconThemeData(
                          size: 22,
                          color: selected ? AppColors.surface : AppColors.ink,
                        ),
                        child: selected
                            ? destination.selectedIcon ?? destination.icon
                            : destination.icon,
                      ),
                      if (selected) ...[
                        const SizedBox(width: AppSpacing.sm),
                        Flexible(
                          child: ExcludeSemantics(
                            child: Text(
                              destination.label,
                              style: AppTypography.caption.copyWith(
                                color: AppColors.surface,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
