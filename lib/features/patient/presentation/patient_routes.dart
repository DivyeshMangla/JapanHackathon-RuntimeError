import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/routing/app_routes.dart';
import '../../../core/routing/role_shell.dart';
import '../../../core/utils/l10n.dart';
import '../../auth/presentation/signed_in_gate.dart';
import '../../education/presentation/learn_screen.dart';
import '../../education/presentation/learn_topic_screen.dart';
import '../../questionnaires/presentation/feedback_screen.dart';
import '../../questionnaires/presentation/self_report_screen.dart';
import '../../questionnaires/presentation/usability_screen.dart';
import 'exercise_detail_screen.dart';
import 'patient_home_screen.dart';
import 'patient_profile_screen.dart';
import 'patient_recordings_screen.dart';
import 'record_screen.dart';
import 'today_exercises_screen.dart';
import 'voice_diary_screen.dart';

/// Patient area: four tabs, each keeping its own navigation stack.
final patientRoutes = StatefulShellRoute.indexedStack(
  builder: (context, state, shell) => SignedInGate(
    child: RoleShell(
      shell: shell,
      destinations: [
        NavigationDestination(
          icon: const Icon(LucideIcons.house),
          label: context.l10n.navHome,
        ),
        NavigationDestination(
          icon: const Icon(LucideIcons.listChecks),
          label: context.l10n.navExercises,
        ),
        NavigationDestination(
          icon: const Icon(LucideIcons.mic),
          label: context.l10n.navRecord,
        ),
        NavigationDestination(
          icon: const Icon(LucideIcons.circleUser),
          label: context.l10n.navProfile,
        ),
      ],
    ),
  ),
  branches: [
    StatefulShellBranch(
      routes: [
        GoRoute(
          path: AppRoutes.patient,
          builder: (context, state) => const PatientHomeScreen(),
          routes: [
            GoRoute(
              path: 'learn',
              builder: (context, state) => const LearnScreen(),
              routes: [
                GoRoute(
                  path: ':topic',
                  builder: (context, state) => LearnTopicScreen(
                    topicName: state.pathParameters['topic']!,
                  ),
                ),
              ],
            ),
            GoRoute(
              path: 'questionnaires/self-report/:week',
              builder: (context, state) => SelfReportScreen(
                week: int.tryParse(state.pathParameters['week']!) ?? 0,
              ),
            ),
            GoRoute(
              path: 'questionnaires/usability',
              builder: (context, state) => const UsabilityScreen(),
            ),
            GoRoute(
              path: 'questionnaires/feedback',
              builder: (context, state) => const FeedbackScreen(),
            ),
          ],
        ),
      ],
    ),
    StatefulShellBranch(
      routes: [
        GoRoute(
          path: AppRoutes.patientExercises,
          builder: (context, state) => const TodayExercisesScreen(),
          routes: [
            GoRoute(
              path: ':exerciseId',
              builder: (context, state) => ExerciseDetailScreen(
                exerciseId: state.pathParameters['exerciseId']!,
              ),
              routes: [
                GoRoute(
                  path: 'diary',
                  builder: (context, state) => VoiceDiaryScreen(
                    exerciseId: state.pathParameters['exerciseId']!,
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
          path: AppRoutes.patientRecord,
          builder: (context, state) => const RecordScreen(),
        ),
      ],
    ),
    StatefulShellBranch(
      routes: [
        GoRoute(
          path: AppRoutes.patientProfile,
          builder: (context, state) => PatientProfileScreen(
            key: ValueKey((state.uri.toString(), state.extra)),
            initialSection: state.uri.queryParameters['section'],
          ),
          routes: [
            GoRoute(
              path: 'recordings',
              builder: (context, state) => const PatientRecordingsScreen(),
            ),
          ],
        ),
        GoRoute(
          path: AppRoutes.patientProgress,
          redirect: (context, state) => AppRoutes.patientProfileProgress,
        ),
      ],
    ),
  ],
);
