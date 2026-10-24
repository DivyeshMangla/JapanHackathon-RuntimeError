import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/routing/app_routes.dart';
import '../../../core/routing/role_shell.dart';
import '../../../core/utils/l10n.dart';
import '../../audit/presentation/access_log_screen.dart';
import '../../auth/domain/user.dart';
import '../../auth/presentation/signed_in_gate.dart';
import 'exercise_editor_screen.dart';
import 'exercise_library_screen.dart';
import 'people_screen.dart';
import 'study_overview_screen.dart';
import 'study_settings_screen.dart';
import 'user_form_screen.dart';

/// Research admin area: study overview, people, exercise library, settings.
final adminRoutes = StatefulShellRoute.indexedStack(
  builder: (context, state, shell) => SignedInGate(
    child: RoleShell(
      shell: shell,
      destinations: [
        NavigationDestination(
          icon: const Icon(LucideIcons.layoutDashboard),
          label: context.l10n.navOverview,
        ),
        NavigationDestination(
          icon: const Icon(LucideIcons.users),
          label: context.l10n.navPeople,
        ),
        NavigationDestination(
          icon: const Icon(LucideIcons.libraryBig),
          label: context.l10n.navLibrary,
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
          path: AppRoutes.admin,
          builder: (context, state) => const StudyOverviewScreen(),
        ),
      ],
    ),
    StatefulShellBranch(
      routes: [
        GoRoute(
          path: AppRoutes.adminPeople,
          builder: (context, state) => const PeopleScreen(),
          routes: [
            GoRoute(
              path: 'new',
              builder: (context, state) => UserFormScreen(
                role: UserRole.values.byName(
                  state.uri.queryParameters['role'] ?? UserRole.parent.name,
                ),
              ),
            ),
          ],
        ),
      ],
    ),
    StatefulShellBranch(
      routes: [
        GoRoute(
          path: AppRoutes.adminLibrary,
          builder: (context, state) => const ExerciseLibraryScreen(),
          routes: [
            GoRoute(
              path: ':exerciseId',
              builder: (context, state) {
                final id = state.pathParameters['exerciseId']!;
                return ExerciseEditorScreen(
                  exerciseId: id == 'new' ? null : id,
                );
              },
            ),
          ],
        ),
      ],
    ),
    StatefulShellBranch(
      routes: [
        GoRoute(
          path: AppRoutes.adminSettings,
          builder: (context, state) => const StudySettingsScreen(),
          routes: [
            GoRoute(
              path: 'access-log',
              builder: (context, state) => const AccessLogScreen(),
            ),
          ],
        ),
      ],
    ),
  ],
);
