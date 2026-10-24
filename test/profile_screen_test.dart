import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:melo/core/routing/app_routes.dart';
import 'package:melo/core/theme/app_theme.dart';
import 'package:melo/core/utils/l10n.dart';
import 'package:melo/features/auth/domain/user.dart';
import 'package:melo/features/auth/presentation/controllers/auth_controller.dart';
import 'package:melo/features/exercises/domain/adherence.dart';
import 'package:melo/features/exercises/domain/patient_activity.dart';
import 'package:melo/features/exercises/presentation/controllers/exercise_controllers.dart';
import 'package:melo/features/patient/presentation/patient_recordings_screen.dart';
import 'package:melo/features/patient/presentation/patient_routes.dart';
import 'package:melo/features/recordings/domain/recording.dart';
import 'package:melo/features/recordings/presentation/controllers/playback_controller.dart';
import 'package:melo/features/recordings/presentation/controllers/recording_controllers.dart';
import 'package:melo/features/recordings/presentation/recording_tile.dart';
import 'package:melo/features/reminders/domain/reminder.dart';
import 'package:melo/features/reminders/presentation/controllers/reminder_controllers.dart';

final _patient = User(
  id: 'p1',
  role: UserRole.patient,
  name: 'Test Patient',
  email: 'patient@example.org',
  createdAt: DateTime(2026),
  participantCode: 'P001',
);

class _Auth extends AuthController {
  @override
  Future<User?> build() async => _patient;
}

class _Playback extends PlaybackController {
  @override
  PlaybackState build() => const PlaybackState();
}

final _recordings = List.generate(
  5,
  (i) => Recording(
    id: '$i',
    patientId: 'p1',
    kind: RecordingKind.practice,
    task: RecordingTask.readingPassage,
    type: RecordingType.homePractice,
    filePath: 'sample-$i.wav',
    durationSec: 10,
    createdAt: DateTime(2026, 10, i + 1),
  ),
);

Future<GoRouter> _pump(
  WidgetTester tester, {
  String route = AppRoutes.patientProfile,
  double scale = 1,
  bool empty = false,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = GoRouter(initialLocation: route, routes: [patientRoutes]);
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authControllerProvider.overrideWith(_Auth.new),
        currentUserProvider.overrideWithValue(_patient),
        playbackProvider.overrideWith(_Playback.new),
        patientActivityProvider.overrideWith(
          (ref, id) async => PatientActivity(
            today: DateTime(2026, 10, 23),
            schedules: [],
            exercises: {},
            completions: [],
            days: Adherence.daily(
              schedules: [],
              completions: [],
              from: DateTime(2026, 8, 29),
              to: DateTime(2026, 10, 23),
            ),
          ),
        ),
        patientRecordingsProvider.overrideWith(
          (ref, id) async => empty ? [] : _recordings,
        ),
        reminderTimesProvider.overrideWith(
          (ref, id) async => [const ReminderTime(9, 0)],
        ),
      ],
      child: MaterialApp.router(
        theme: AppTheme.light,
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

void main() {
  testWidgets(
    'Profile combines progress and three newest recordings with four tabs',
    (tester) async {
      final router = await _pump(tester);
      expect(find.text('Your progress'), findsOneWidget);
      expect(find.text('Last 14 days'), findsOneWidget);
      expect(find.byTooltip('Progress'), findsNothing);
      for (final label in ['Home', 'Exercises', 'Record']) {
        expect(find.byTooltip(label), findsOneWidget);
      }
      final tiles = tester
          .widgetList<RecordingTile>(find.byType(RecordingTile))
          .toList();
      expect(tiles.map((tile) => tile.recording.id), ['4', '3', '2']);
      await tester.ensureVisible(find.text('View all'));
      await tester.tap(find.text('View all'));
      await tester.pumpAndSettle();
      expect(find.byType(PatientRecordingsScreen), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byWidgetPredicate(
          (w) => w is RecordingTile && w.recording.id == '0',
        ),
        200,
      );
      expect(
        find.byWidgetPredicate(
          (w) => w is RecordingTile && w.recording.id == '0',
        ),
        findsOneWidget,
      );
      router.pop();
      await tester.pumpAndSettle();
      expect(find.text('Your progress'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('legacy Progress link opens Profile at progress', (tester) async {
    final router = await _pump(tester, route: AppRoutes.patientProgress);
    expect(
      router.routeInformationProvider.value.uri.toString(),
      AppRoutes.patientProfileProgress,
    );
    expect(tester.getTopLeft(find.text('Your progress')).dy, lessThan(150));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'reminder shortcut positions after async sections and opens editor',
    (tester) async {
      await _pump(tester, route: AppRoutes.patientProfileReminders);
      final label = find.text('Daily reminders');
      expect(tester.getTopLeft(label).dy, lessThan(500));
      await tester.ensureVisible(find.byType(InputChip));
      await tester.tap(find.byType(InputChip));
      await tester.pumpAndSettle();
      expect(find.byType(TimePickerDialog), findsOneWidget);
      expect(find.text('Edit reminder'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('empty profile supports enlarged text and account details', (
    tester,
  ) async {
    await _pump(tester, scale: 2, empty: true);
    expect(find.text('No recordings yet'), findsOneWidget);
    await tester.tap(find.byTooltip('Account details'));
    await tester.pumpAndSettle();
    expect(find.text('patient@example.org'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
