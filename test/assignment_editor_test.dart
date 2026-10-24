import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:melo/core/theme/app_theme.dart';
import 'package:melo/core/utils/dates.dart';
import 'package:melo/core/utils/l10n.dart';
import 'package:melo/features/auth/domain/user.dart';
import 'package:melo/features/auth/presentation/controllers/auth_controller.dart';
import 'package:melo/features/exercises/domain/exercise.dart';
import 'package:melo/features/exercises/domain/patient_activity.dart';
import 'package:melo/features/exercises/domain/schedule.dart';
import 'package:melo/features/exercises/presentation/controllers/exercise_controllers.dart';
import 'package:melo/features/recordings/domain/probe_schedule.dart';
import 'package:melo/features/study/domain/participant_status.dart';
import 'package:melo/features/therapist/domain/participant_summary.dart';
import 'package:melo/features/therapist/presentation/assignment_editor_screen.dart';
import 'package:melo/features/therapist/presentation/controllers/caseload_controllers.dart';
import 'package:melo/shared/widgets/labeled_text_field.dart';
import 'support/exercise_fixtures.dart';

/// Records assignments instead of writing them.
class _RecordingScheduleActions implements ScheduleActions {
  final assigned = <(String, Dosage)>[];

  @override
  Future<void> assign({
    required String patientId,
    required Exercise exercise,
    required Dosage dosage,
    required String therapistId,
  }) async => assigned.add((exercise.id, dosage));

  @override
  Future<void> revise(
    Schedule current,
    Dosage dosage, {
    required String therapistId,
  }) => throw UnimplementedError();

  @override
  Future<void> end(Schedule current) => throw UnimplementedError();
}

final _today = dateOnly(DateTime.now());

final _therapist = User(
  id: 'therapist-01',
  role: UserRole.therapist,
  name: 'Test Therapist',
  email: 't@example.org',
  createdAt: _today,
);

final _participant = ParticipantSummary(
  patient: User(
    id: 'p1',
    role: UserRole.patient,
    name: 'Test Patient',
    email: 'p1@example.org',
    createdAt: _today,
    participantCode: 'P001',
    therapistId: 'therapist-01',
  ),
  activity: PatientActivity(
    today: _today,
    schedules: const [],
    exercises: fixtureLibrary,
    completions: const [],
    days: const [],
  ),
  recordings: const [],
  lowAdherence: false,
  status: ParticipantStatus.awaitingProbe,
  probeDue: ProbeDue(nextDue: _today, isBaseline: true),
);

Future<_RecordingScheduleActions> _openEditor(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390, 844) * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final actions = _RecordingScheduleActions();
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const Scaffold(body: Text('Participant')),
        routes: [
          GoRoute(
            path: 'assign',
            builder: (context, state) =>
                const AssignmentEditorScreen(patientId: 'p1'),
          ),
        ],
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentUserProvider.overrideWithValue(_therapist),
        caseloadParticipantProvider.overrideWith(
          (ref, id) async => _participant,
        ),
        exerciseLibraryProvider.overrideWith(
          (ref) async => [
            for (final e in fixtureExercises)
              e.approve(by: 'admin', at: _today),
          ],
        ),
        scheduleActionsProvider.overrideWithValue(actions),
      ],
      child: MaterialApp.router(
        theme: AppTheme.light,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
  unawaited(router.push('/assign'));
  await tester.pumpAndSettle();
  return actions;
}

Future<void> _tapExercise(WidgetTester tester, String title) async {
  await tester.scrollUntilVisible(
    find.text(title),
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text(title));
  await tester.pump();
}

void main() {
  testWidgets('several exercises are assigned from a pinned action', (
    tester,
  ) async {
    final actions = await _openEditor(tester);

    // Nothing is selected, so there is no action to take yet.
    expect(find.text('Continue'), findsNothing);

    await _tapExercise(tester, 'Plain exercise');
    expect(find.text('1 exercise selected'), findsOneWidget);
    await _tapExercise(tester, 'Exercise needing instructions');
    expect(find.text('2 exercises selected'), findsOneWidget);

    // The action is reachable without scrolling to the end of the list.
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Set the dosage for 2 exercises'), findsOneWidget);

    // The second exercise needs the therapist's own instructions.
    await tester.tap(find.text('Assign'));
    await tester.pumpAndSettle();
    expect(actions.assigned, isEmpty);
    expect(find.text('Check Exercise needing instructions'), findsOneWidget);

    // The field below the fold shows its message once it is scrolled to.
    await tester.scrollUntilVisible(
      find.text('Instructions for this patient'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    final instructions = find.descendant(
      of: find.ancestor(
        of: find.text('Instructions for this patient'),
        matching: find.byType(LabeledTextField),
      ),
      matching: find.byType(TextFormField),
    );
    await tester.pumpAndSettle();
    expect(
      find.text(
        'This exercise depends on material you choose. '
        "Write the patient's instructions.",
      ),
      findsOneWidget,
    );
    await tester.enterText(instructions, 'mi, me, mo, no');
    await tester.tap(find.text('Assign'));
    await tester.pumpAndSettle();

    expect(actions.assigned.map((a) => a.$1), ['ex-plain', 'ex-instructions']);
    expect(actions.assigned.last.$2.instructions, 'mi, me, mo, no');
    expect(actions.assigned.first.$2.weekdays, {1, 2, 3, 4, 5, 6, 7});
    expect(find.text('Participant'), findsOneWidget);
  });

  testWidgets('selection can be changed before assigning', (tester) async {
    await _openEditor(tester);
    await _tapExercise(tester, 'Plain exercise');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Change selection'));
    await tester.pumpAndSettle();
    await _tapExercise(tester, 'Plain exercise');
    expect(find.text('Continue'), findsNothing);
  });
}
