import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:melo/core/theme/app_theme.dart';
import 'package:melo/core/utils/dates.dart';
import 'package:melo/core/utils/l10n.dart';
import 'package:melo/features/admin/presentation/exercise_library_screen.dart';
import 'package:melo/features/auth/domain/user.dart';
import 'package:melo/features/auth/presentation/controllers/auth_controller.dart';
import 'package:melo/features/exercises/domain/adherence.dart';
import 'package:melo/features/exercises/domain/patient_activity.dart';
import 'package:melo/features/exercises/domain/schedule.dart';
import 'package:melo/features/exercises/presentation/controllers/exercise_controllers.dart';
import 'package:melo/features/patient/presentation/exercise_detail_screen.dart';
import 'package:melo/features/patient/presentation/voice_diary_screen.dart';
import 'package:melo/features/usage/domain/usage_event.dart';
import 'package:melo/features/usage/presentation/controllers/usage_controllers.dart';
import 'support/exercise_fixtures.dart';

class _SilentUsageLogger implements UsageLogger {
  @override
  Future<void> record(
    UsageAction action, {
    String detail = '',
    User? user,
  }) async {}
}

final _today = dateOnly(DateTime.now());

final _patient = User(
  id: 'p1',
  role: UserRole.patient,
  name: 'Test Patient',
  email: 'p1@example.org',
  createdAt: _today,
  participantCode: 'P001',
);

Schedule _assign(String exerciseId, {String instructions = ''}) => Schedule(
  id: 'sched-$exerciseId',
  patientId: 'p1',
  exerciseId: exerciseId,
  weekdays: const {1, 2, 3, 4, 5, 6, 7},
  effectiveFrom: _today,
  instructions: instructions,
);

PatientActivity _activity() {
  final schedules = [
    _assign('ex-instructions', instructions: 'Use the visual cards.'),
    _assign('ex-diary'),
  ];
  return PatientActivity(
    today: _today,
    schedules: schedules,
    exercises: fixtureLibrary,
    completions: const [],
    days: Adherence.daily(
      schedules: schedules,
      completions: const [],
      from: _today,
      to: _today,
    ),
  );
}

Future<void> _pump(WidgetTester tester, Widget screen) async {
  tester.view.physicalSize = const Size(390, 844) * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final activity = _activity();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentUserProvider.overrideWithValue(_patient),
        usageLoggerProvider.overrideWithValue(_SilentUsageLogger()),
        patientActivityProvider.overrideWith((ref, id) async => activity),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: screen,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('exercise detail shows instructions, caution and steps', (
    tester,
  ) async {
    await _pump(
      tester,
      const ExerciseDetailScreen(exerciseId: 'ex-instructions'),
    );
    final scrollable = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.text('Use the visual cards.'),
      200,
      scrollable: scrollable,
    );
    expect(find.text('Caution'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Mark session done'),
      200,
      scrollable: scrollable,
    );
    expect(find.text('Steps'), findsOneWidget);
  });

  testWidgets('a diary exercise is completed through the diary', (
    tester,
  ) async {
    await _pump(tester, const ExerciseDetailScreen(exerciseId: 'ex-diary'));
    await tester.scrollUntilVisible(
      find.text("Fill in today's diary"),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    // A single-sentence description is not repeated as a step list.
    expect(find.text('Steps'), findsNothing);
  });

  testWidgets('diary asks for the required answers before saving', (
    tester,
  ) async {
    await _pump(tester, const VoiceDiaryScreen(exerciseId: 'ex-diary'));
    expect(find.text('About how long did you speak today?'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Save diary entry'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Save diary entry'));
    await tester.pump();
    expect(
      find.text('Answer this question.', skipOffstage: false),
      findsNWidgets(2),
    );
  });

  testWidgets('diary for an exercise not due today says so', (tester) async {
    await _pump(tester, const VoiceDiaryScreen(exerciseId: 'ex-plain'));
    expect(find.text('No diary entry due'), findsOneWidget);
  });

  testWidgets('admin library groups the library by program', (tester) async {
    tester.view.physicalSize = const Size(390, 844) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          exerciseLibraryProvider.overrideWith((ref) async => fixtureExercises),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const ExerciseLibraryScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Fixture program A'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Fixture program B'),
      600,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Fixture program B'), findsOneWidget);
  });
}
