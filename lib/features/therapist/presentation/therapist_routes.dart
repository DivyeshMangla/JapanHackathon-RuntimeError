import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/routing/app_routes.dart';
import '../../../core/routing/role_shell.dart';
import '../../../core/utils/l10n.dart';
import '../../auth/presentation/signed_in_gate.dart';
import '../../motor/presentation/therapist_drawing_screen.dart';
import '../../usage/presentation/usage_log_screen.dart';
import '../../useful_words/presentation/word_screens.dart';
import 'participant_detail_screen.dart';
import 'participants_screen.dart';
import 'therapist_dashboard_screen.dart';
import 'voice_samples_screen.dart';

/// Therapist area: overview, participants and voice samples tabs.
final therapistRoutes = StatefulShellRoute.indexedStack(
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
          label: context.l10n.navParticipants,
        ),
        NavigationDestination(
          icon: const Icon(LucideIcons.audioLines),
          label: context.l10n.navVoiceSamples,
        ),
      ],
    ),
  ),
  branches: [
    StatefulShellBranch(
      routes: [
        GoRoute(
          path: AppRoutes.therapist,
          builder: (context, state) => const TherapistDashboardScreen(),
        ),
      ],
    ),
    StatefulShellBranch(
      routes: [
        GoRoute(
          path: AppRoutes.therapistParticipants,
          builder: (context, state) => const ParticipantsScreen(),
          routes: [
            GoRoute(
              path: ':patientId',
              builder: (context, state) => ParticipantDetailScreen(
                patientId: state.pathParameters['patientId']!,
              ),
              routes: [
                GoRoute(
                  path: 'usage',
                  builder: (context, state) => UsageLogScreen(
                    patientId: state.pathParameters['patientId']!,
                  ),
                ),
                GoRoute(
                  path: 'words',
                  builder: (context, state) => TherapistWordsScreen(
                    patientId: state.pathParameters['patientId']!,
                  ),
                ),
                GoRoute(
                  path: 'drawing',
                  builder: (context, state) => TherapistDrawingScreen(
                    patientId: state.pathParameters['patientId']!,
                  ),
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
          path: AppRoutes.therapistRecordings,
          builder: (context, state) {
            final patientId = state.uri.queryParameters['patient'];
            // Keyed so arriving with a different filter resets the screen.
            return VoiceSamplesScreen(
              key: ValueKey(patientId),
              initialPatientId: patientId,
            );
          },
        ),
      ],
    ),
  ],
);
