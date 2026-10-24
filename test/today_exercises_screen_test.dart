import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:melo/core/theme/app_theme.dart';
import 'package:melo/core/utils/dates.dart';
import 'package:melo/core/utils/l10n.dart';
import 'package:melo/features/auth/domain/user.dart';
import 'package:melo/features/auth/presentation/controllers/auth_controller.dart';
import 'package:melo/features/exercises/domain/adherence.dart';
import 'package:melo/features/exercises/domain/completion.dart';
import 'package:melo/features/exercises/domain/exercise.dart';
import 'package:melo/features/exercises/domain/patient_activity.dart';
import 'package:melo/features/exercises/domain/schedule.dart';
import 'package:melo/features/exercises/presentation/controllers/exercise_controllers.dart';
import 'package:melo/features/patient/presentation/today_exercises_screen.dart';

final _today = dateOnly(DateTime.now());

final _patient = User(
  id: 'p1',
  role: UserRole.patient,
  name: 'Test Patient',
  email: 'p1@example.org',
  createdAt: _today,
  participantCode: 'P001',
);

Exercise _exercise(String id, String title) => Exercise(
  id: id,
  title: title,
  program: 'Semi-occluded vocal tract',
  summary: '',
  steps: const [],
  durationMinutes: 5,
  repetitions: 5,
);

Schedule _assign(String exerciseId, {int sessions = 1}) => Schedule(
  id: 'sched-$exerciseId',
  patientId: 'p1',
  exerciseId: exerciseId,
  weekdays: const {1, 2, 3, 4, 5, 6, 7},
  effectiveFrom: addDays(_today, -historyDays),
  sessionsPerDay: sessions,
  repetitions: 10,
);

Completion _done(String exerciseId, int n) => Completion(
  id: '$exerciseId-$n',
  patientId: 'p1',
  exerciseId: exerciseId,
  day: _today,
  completedAt: _today.add(Duration(minutes: n)),
);

PatientActivity _activity() {
  final exercises = [
    _exercise('a', 'Humming'),
    _exercise('b', 'Lip trills'),
    _exercise('c', 'Straw phonation'),
  ];
  final schedules = [
    _assign('a'),
    _assign('b', sessions: 2),
    _assign('c', sessions: 2),
  ];
  final completions = [_done('a', 1), _done('c', 1)];
  return PatientActivity(
    today: _today,
    schedules: schedules,
    exercises: {for (final e in exercises) e.id: e},
    completions: completions,
    days: Adherence.daily(
      schedules: schedules,
      completions: completions,
      from: addDays(_today, -(historyDays - 1)),
      to: _today,
    ),
  );
}

Future<void> _pump(
  WidgetTester tester, {
  double width = 390,
  double scale = 1,
}) async {
  tester.view.physicalSize = Size(width, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final activity = _activity();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentUserProvider.overrideWithValue(_patient),
        patientActivityProvider.overrideWith((ref, id) async => activity),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: const TodayExercisesScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('features the first unfinished exercise', (tester) async {
    await _pump(tester);

    expect(find.text('Up next'), findsOneWidget);
    expect(find.text('Start exercise'), findsOneWidget);
    expect(find.text('Lip trills'), findsOneWidget);
    expect(find.text('2/5'), findsOneWidget);
  });

  testWidgets('shows completed, partial and pending sessions', (tester) async {
    await _pump(tester);

    expect(find.text('Completed'), findsOneWidget);
    expect(find.byTooltip('Undo session 1 for Humming'), findsOneWidget);
    expect(find.text('Mark session 1'), findsOneWidget);
    expect(find.text('Mark session 2'), findsOneWidget);
    expect(
      find.byTooltip('Undo session 1 for Straw phonation'),
      findsOneWidget,
    );
  });

  testWidgets('fits a narrow phone with enlarged text', (tester) async {
    await _pump(tester, width: 320, scale: 2);

    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(find.text('Mark session 2'), 200);
    expect(tester.takeException(), isNull);
  });
}
