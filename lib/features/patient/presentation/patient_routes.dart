import 'package:go_router/go_router.dart';

import '../../../core/routing/app_routes.dart';
import '../../auth/presentation/signed_in_gate.dart';
import '../../expressions/presentation/child_expressions_screen.dart';
import '../../motor/presentation/child_drawing_screen.dart';
import '../../motor/presentation/motor_practice_screen.dart';
import '../../progress/presentation/child_progress_screen.dart';
import '../../useful_words/presentation/word_screens.dart';
import 'child_home_screen.dart';

/// The child's area: one home of picture buttons, each opening its own
/// page with a back button, so there is no tab bar to learn.
final patientRoutes = GoRoute(
  path: AppRoutes.patient,
  builder: (context, state) => const SignedInGate(child: ChildHomeScreen()),
  routes: [
    GoRoute(
      path: 'expressions',
      builder: (context, state) =>
          const SignedInGate(child: ChildExpressionsScreen()),
    ),
    GoRoute(
      path: 'progress',
      builder: (context, state) =>
          const SignedInGate(child: ChildProgressScreen()),
    ),
    GoRoute(
      path: 'words',
      builder: (context, state) =>
          const SignedInGate(child: ChildWordsScreen()),
    ),
    GoRoute(
      path: 'drawing',
      builder: (context, state) =>
          const SignedInGate(child: ChildDrawingScreen()),
      routes: [
        GoRoute(
          path: ':exerciseId',
          builder: (context, state) => SignedInGate(
            child: MotorPracticeScreen(
              exerciseId: state.pathParameters['exerciseId']!,
            ),
          ),
        ),
      ],
    ),
  ],
);
