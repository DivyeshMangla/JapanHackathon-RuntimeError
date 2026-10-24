// UI review fixtures only. Run with flutter test --dart-define=UI_PHASE=before
// tool/capture_ui_comparison.dart (repeat with UI_PHASE=after after edits).
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:melo/core/routing/app_routes.dart';
import 'package:melo/core/theme/app_colors.dart';
import 'package:melo/core/theme/app_theme.dart';
import 'package:melo/core/utils/l10n.dart';
import 'package:melo/features/auth/domain/user.dart';
import 'package:melo/features/auth/presentation/controllers/auth_controller.dart';
import 'package:melo/features/exercises/domain/adherence.dart';
import 'package:melo/features/exercises/domain/completion.dart';
import 'package:melo/features/exercises/domain/exercise.dart';
import 'package:melo/features/exercises/domain/patient_activity.dart';
import 'package:melo/features/exercises/domain/schedule.dart';
import 'package:melo/features/exercises/presentation/controllers/exercise_controllers.dart';
import 'package:melo/features/patient/presentation/patient_routes.dart';
import 'package:melo/features/recordings/domain/probe_schedule.dart';
import 'package:melo/features/recordings/presentation/controllers/playback_controller.dart';
import 'package:melo/features/recordings/presentation/controllers/recording_controllers.dart';
import 'package:melo/features/recordings/presentation/controllers/recording_session.dart';
import 'package:melo/features/reminders/domain/reminder.dart';
import 'package:melo/features/reminders/presentation/controllers/reminder_controllers.dart';

final today = DateTime(2026, 10, 23);
final patient = User(
  id: 'preview',
  role: UserRole.patient,
  name: 'Alex Morgan',
  email: 'alex@example.org',
  createdAt: today,
  participantCode: 'P001',
  therapistId: 'therapist',
);

class PreviewAuth extends AuthController {
  @override
  Future<User?> build() async => patient;
}

class PreviewPlayback extends PlaybackController {
  @override
  PlaybackState build() => const PlaybackState();
}

class PreviewSession extends RecordingSession {
  PreviewSession(this.active);
  final bool active;
  void sample(double level) => state = state.copyWith(level: level);
  @override
  RecordingSessionState build() => active
      ? const RecordingSessionState(
          stage: RecordingStage.recording,
          elapsed: Duration(seconds: 24),
          level: 0.62,
          leadInDone: true,
        )
      : const RecordingSessionState();
}

const _fixtureExercises = [
  Exercise(
    id: 'fixture-a',
    title: 'Fixture exercise A',
    program: 'Fixture program',
    summary: 'Placeholder for UI review.',
    steps: ['Placeholder for UI review.'],
    durationMinutes: 5,
    repetitions: 5,
  ),
  Exercise(
    id: 'fixture-b',
    title: 'Fixture exercise B',
    program: 'Fixture program',
    summary: 'Placeholder for UI review.',
    steps: ['Placeholder for UI review.'],
    durationMinutes: 5,
    repetitions: 5,
  ),
  Exercise(
    id: 'fixture-c',
    title: 'Fixture exercise C',
    program: 'Fixture program',
    summary: 'Placeholder for UI review.',
    steps: ['Placeholder for UI review.'],
    durationMinutes: 5,
    repetitions: 5,
  ),
];

PatientActivity activity() {
  final ids = [for (final e in _fixtureExercises) e.id];
  final schedules = [
    for (final id in ids)
      Schedule(
        id: 'schedule-$id',
        patientId: patient.id,
        exerciseId: id,
        weekdays: {1, 2, 3, 4, 5, 6, 7},
        effectiveFrom: today.subtract(const Duration(days: 55)),
        repetitions: 10,
      ),
  ];
  final completions = <Completion>[];
  for (var d = 0; d < 56; d++) {
    for (var e = 0; e < 3; e++) {
      if (d == 0 ? e > 0 : d % 5 == 0 && e == 2) continue;
      final day = today.subtract(Duration(days: d));
      completions.add(
        Completion(
          id: '$d-$e',
          patientId: patient.id,
          exerciseId: ids[e],
          day: day,
          completedAt: day.add(const Duration(hours: 9)),
        ),
      );
    }
  }
  return PatientActivity(
    today: today,
    schedules: schedules,
    exercises: {for (final e in _fixtureExercises) e.id: e},
    completions: completions,
    days: Adherence.daily(
      schedules: schedules,
      completions: completions,
      from: today.subtract(const Duration(days: 55)),
      to: today,
    ),
  );
}

void main() {
  testWidgets('capture six matching patient views', (tester) async {
    const phase = String.fromEnvironment('UI_PHASE', defaultValue: 'after');
    final directory = Directory('docs/ui-comparison/$phase');
    await tester.runAsync(() => directory.create(recursive: true));
    final fonts = FontLoader('NunitoSans');
    for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
      fonts.addFont(rootBundle.load('assets/fonts/NunitoSans-$weight.ttf'));
    }
    await fonts.load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    await (FontLoader('packages/lucide_icons_flutter/Lucide')..addFont(
          rootBundle.load('packages/lucide_icons_flutter/assets/lucide.ttf'),
        ))
        .load();
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    const pages = {
      '01-home': AppRoutes.patient,
      '02-exercises': AppRoutes.patientExercises,
      '03-record-setup': AppRoutes.patientRecord,
      '04-recording': AppRoutes.patientRecord,
      '05-profile': AppRoutes.patientProfile,
      '06-learn': AppRoutes.patientLearn,
    };
    for (final page in pages.entries) {
      final router = GoRouter(
        initialLocation: page.value,
        routes: [patientRoutes],
      );
      await tester.pumpWidget(
        ProviderScope(
          key: ValueKey(page.key),
          overrides: [
            authControllerProvider.overrideWith(PreviewAuth.new),
            currentUserProvider.overrideWithValue(patient),
            userByIdProvider.overrideWith(
              (ref, id) async => User(
                id: 'therapist',
                role: UserRole.therapist,
                name: 'Dr. Taylor Reed',
                email: 'therapist@example.org',
                createdAt: today,
              ),
            ),
            patientActivityProvider.overrideWith((ref, id) async => activity()),
            probeDueProvider.overrideWith(
              (ref, id) async => ProbeDue(
                nextDue: today.add(const Duration(days: 3)),
                isBaseline: false,
              ),
            ),
            reminderTimesProvider.overrideWith(
              (ref, id) async => [
                const ReminderTime(9, 0),
                const ReminderTime(18, 0),
              ],
            ),
            patientRecordingsProvider.overrideWith((ref, id) async => []),
            playbackProvider.overrideWith(PreviewPlayback.new),
            recordingSessionProvider.overrideWith(
              () => PreviewSession(page.key == '04-recording'),
            ),
          ],
          child: MaterialApp.router(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            routerConfig: router,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => RepaintBoundary(
              key: const ValueKey('capture'),
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: AppColors.pageGradient,
                ),
                child: child!,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      if (page.key == '04-recording') {
        final container = ProviderScope.containerOf(
          tester.element(find.byType(MaterialApp)),
        );
        final session =
            container.read(recordingSessionProvider.notifier) as PreviewSession;
        // Deterministic microphone samples for the preview, never production.
        for (final level in [
          .08,
          .12,
          .21,
          .35,
          .54,
          .72,
          .61,
          .43,
          .27,
          .18,
          .12,
          .08,
          .15,
          .32,
          .58,
          .81,
          .69,
          .48,
          .31,
          .16,
          .09,
          .13,
          .26,
          .41,
          .65,
          .87,
          .73,
          .52,
          .35,
          .22,
          .14,
          .24,
          .39,
          .51,
          .62,
        ]) {
          session.sample(level);
          await tester.pump(const Duration(milliseconds: 80));
        }
      }
      expect(tester.takeException(), isNull, reason: page.key);
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const ValueKey('capture')),
      );
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(
          '${directory.path}/${page.key}.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
      await tester.pumpWidget(const SizedBox());
      router.dispose();
    }
  });
}
