import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/routing/app_routes.dart';
import '../../../core/routing/role_shell.dart';
import '../../../core/utils/l10n.dart';
import '../../auth/presentation/signed_in_gate.dart';
import 'child_detail_screen.dart';
import 'consent_screen.dart';
import 'parent_home_screen.dart';
import 'parent_settings_screen.dart';

/// Parent area: the family tab and settings, each with its own stack.
final parentRoutes = StatefulShellRoute.indexedStack(
  builder: (context, state, shell) => SignedInGate(
    child: RoleShell(
      shell: shell,
      destinations: [
        NavigationDestination(
          icon: const Icon(LucideIcons.house),
          label: context.l10n.navFamily,
        ),
        NavigationDestination(
          icon: const Icon(LucideIcons.settings),
          label: context.l10n.navSettings,
        ),
      ],
    ),
  ),
  branches: [
    StatefulShellBranch(
      routes: [
        GoRoute(
          path: AppRoutes.parent,
          builder: (context, state) => const ParentHomeScreen(),
          routes: [
            GoRoute(
              path: 'children/:childId',
              builder: (context, state) =>
                  ChildDetailScreen(childId: state.pathParameters['childId']!),
              routes: [
                GoRoute(
                  path: 'consent',
                  builder: (context, state) =>
                      ConsentScreen(childId: state.pathParameters['childId']!),
                ),
              ],
            ),
          ],
        ),
      ],
    ),
    StatefulShellBranch(
      routes: [
        GoRoute(
          path: AppRoutes.parentSettings,
          builder: (context, state) => const ParentSettingsScreen(),
        ),
      ],
    ),
  ],
);
