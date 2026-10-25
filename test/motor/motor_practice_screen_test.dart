import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:melo/core/errors/app_failure.dart';
import 'package:melo/core/theme/app_theme.dart';
import 'package:melo/core/utils/l10n.dart';
import 'package:melo/features/auth/domain/user.dart';
import 'package:melo/features/auth/presentation/controllers/auth_controller.dart';
import 'package:melo/features/motor/data/motor_photo_picker.dart';
import 'package:melo/features/motor/data/motor_repository_providers.dart';
import 'package:melo/features/motor/domain/motor.dart';
import 'package:melo/features/motor/domain/motor_repository.dart';
import 'package:melo/features/motor/presentation/motor_practice_screen.dart';

final _photo = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAusB9Wl6o1sAAAAASUVORK5CYII=',
);
const _exercise = MotorExercise(
  id: 'motor-lines',
  name: 'Little paths',
  description: 'Draw three lines',
  minutes: 1,
  steps: [],
  strokes: [],
);
const _record = MotorRecord(
  planId: 'plan',
  exerciseIds: ['motor-lines'],
  submissions: [],
  consented: true,
);

class _Photos extends MotorPhotoPicker {
  Uint8List? captureResult = _photo;
  int captures = 0;
  int galleryPicks = 0;

  @override
  Future<Uint8List?> capture() async {
    captures++;
    return captureResult;
  }

  @override
  Future<Uint8List?> pick() async {
    galleryPicks++;
    return _photo;
  }
}

class _Repository implements MotorRepository {
  final uploads = <({String id, Uint8List bytes})>[];
  bool failUploads = true;
  bool rejectPhotos = false;
  bool pendingPhotos = false;
  MotorSubmission? receipt;
  @override
  Future<List<MotorExercise>> exercises() async => [_exercise];
  @override
  Future<MotorRecord> recordFor(String childId) async => receipt == null
      ? _record
      : MotorRecord(
          planId: 'plan',
          exerciseIds: ['motor-lines'],
          submissions: [receipt!],
          consented: true,
        );
  @override
  Future<void> submit({
    required String childId,
    required String planId,
    required String exerciseId,
    required String submissionId,
    required Uint8List photo,
    required DateTime day,
  }) async {
    uploads.add((id: submissionId, bytes: Uint8List.fromList(photo)));
    if (failUploads) {
      throw const NetworkFailure(
        NetworkProblem.rejected,
        status: 503,
        serverMessage: 'Retry later',
      );
    }
    receipt = MotorSubmission(
      id: submissionId,
      exerciseId: exerciseId,
      practiceDay: '2026-10-25',
      status: pendingPhotos
          ? MotorAnalysisStatus.processing
          : MotorAnalysisStatus.ready,
      createdAt: DateTime(2026, 10, 25),
      captureFeedback: rejectPhotos
          ? const MotorCaptureFeedback(
              replacementRequired: true,
              reason: MotorRetakeReason.unrelatedPhoto,
            )
          : null,
    );
  }

  @override
  Future<void> assign({
    required String childId,
    required String title,
    required List<String> exerciseIds,
  }) async {}
  @override
  Future<Uint8List> photo(String submissionId) async => _photo;
  @override
  Future<void> review(
    String submissionId,
    String note, {
    MotorTherapistOutcome outcome = MotorTherapistOutcome.notAssessed,
  }) async {}
  @override
  Future<void> retryAnalysis(String submissionId) async {}
}

Future<void> _open(
  WidgetTester tester,
  _Photos photos,
  _Repository repository,
) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentUserProvider.overrideWithValue(
          User(
            id: 'child',
            role: UserRole.patient,
            name: 'Child',
            email: '',
            createdAt: DateTime(2026),
          ),
        ),
        motorPhotoPickerProvider.overrideWithValue(photos),
        motorRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const MotorPracticeScreen(exerciseId: 'motor-lines'),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'camera preview sends original bytes and preserves the ID on retry',
    (tester) async {
      final photos = _Photos();
      final repository = _Repository();
      await _open(tester, photos, repository);
      await tester.tap(find.text('Take a practice photo'));
      await tester.pumpAndSettle();
      expect(photos.captures, 1);
      expect(photos.galleryPicks, 0);
      await tester.scrollUntilVisible(find.byType(Image), 200);
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsOneWidget);
      await tester.tap(find.text('Send to my therapist'));
      await tester.pumpAndSettle();
      expect(find.text('Retry later'), findsOneWidget);
      await tester.tap(find.text('Send to my therapist'));
      await tester.pumpAndSettle();
      expect(repository.uploads, hasLength(2));
      expect(repository.uploads.first.id, repository.uploads.last.id);
      expect(repository.uploads.last.bytes, _photo);
      await tester.scrollUntilVisible(find.byType(Image), 200);
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('camera cancellation still allows choosing a gallery photo', (
    tester,
  ) async {
    final photos = _Photos()..captureResult = null;
    await _open(tester, photos, _Repository());
    await tester.tap(find.text('Take a practice photo'));
    await tester.pumpAndSettle();
    expect(find.text('Send to my therapist'), findsNothing);
    await tester.tap(find.text('Choose practice photo'));
    await tester.pumpAndSettle();
    expect(photos.galleryPicks, 1);
    await tester.scrollUntilVisible(find.byType(Image), 200);
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsOneWidget);
    expect(find.text('Send to my therapist'), findsOneWidget);
  });

  testWidgets(
    'unrelated photo asks for replacement and a new photo gets a new submission',
    (tester) async {
      final repository = _Repository()
        ..failUploads = false
        ..rejectPhotos = true;
      await _open(tester, _Photos(), repository);
      await tester.tap(find.text('Take a practice photo'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Send to my therapist'));
      await tester.tap(find.text('Send to my therapist'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Please take or choose a photo of your drawing on paper, then send it again.',
        ),
        findsOneWidget,
      );
      expect(find.text('Send to my therapist'), findsNothing);
      expect(repository.receipt!.countsAsPractice, isFalse);
      await tester.ensureVisible(find.text('Choose a different photo'));
      await tester.tap(find.text('Choose a different photo'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Send to my therapist'));
      await tester.tap(find.text('Send to my therapist'));
      await tester.pumpAndSettle();
      expect(repository.uploads, hasLength(2));
      expect(repository.uploads.first.id, isNot(repository.uploads.last.id));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a photo still being checked counts as sent without waiting on the child',
    (tester) async {
      final repository = _Repository()
        ..failUploads = false
        ..pendingPhotos = true;
      await _open(tester, _Photos(), repository);
      await tester.tap(find.text('Take a practice photo'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Send to my therapist'));
      await tester.tap(find.text('Send to my therapist'));
      await tester.pump();
      for (var attempt = 0; attempt < 17; attempt++) {
        await tester.pump(const Duration(seconds: 2));
      }
      await tester.pumpAndSettle();
      expect(
        find.text('Your drawing is on its way to your therapist.'),
        findsOneWidget,
      );
      expect(find.text('Check my photo'), findsNothing);
      expect(repository.uploads, hasLength(1));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 2));
      expect(tester.takeException(), isNull);
    },
  );
}
