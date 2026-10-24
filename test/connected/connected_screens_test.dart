import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:melo/core/errors/connected_failure.dart';
import 'package:melo/core/theme/app_theme.dart';
import 'package:melo/core/utils/l10n.dart';
import 'package:melo/data/setup_repository.dart';
import 'package:melo/features/connected/data/connected_service.dart';
import 'package:melo/features/connected/data/motor_photo_picker.dart';
import 'package:melo/features/connected/domain/connected_models.dart';
import 'package:melo/features/connected/presentation/connected_app.dart';
import 'package:melo/features/connected/presentation/motor_practice_page.dart';

class _MemorySecrets implements SecretStore {
  final values = <String, String>{};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async => values[key] = value;
  @override
  Future<void> clear() async => values.clear();
}

class _TestPhotoPicker extends MotorPhotoPicker {
  _TestPhotoPicker(this.bytes);
  final Uint8List bytes;
  @override
  Future<Uint8List?> pick() async => bytes;
}

class _PhotoUploadService extends ConnectedService {
  _PhotoUploadService(super.baseUrl, super.box, super.secrets);
  bool reject = true;
  final uploads = <({String id, List<int> bytes})>[];
  @override
  Future<void> submitMotorPhoto({
    required String submissionId,
    required String planId,
    required String exerciseId,
    required List<int> photo,
    required String practiceDay,
  }) async {
    uploads.add((id: submissionId, bytes: List.of(photo)));
    if (reject) {
      throw const ConnectedFailure(
        ConnectedFailureReason.rejected,
        status: 503,
        serverMessage: 'Retry later',
      );
    }
  }
}

void main() {
  late Directory directory;
  late Box<String> box;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('connected-screens-');
    Hive.init(directory.path);
    box = await Hive.openBox<String>(
      'connected_screens',
      encryptionCipher: HiveAesCipher(List.generate(32, (i) => i)),
    );
  });

  tearDown(() async {
    await box.close();
    await directory.delete(recursive: true);
  });

  testWidgets(
    'failed photo upload retains the preview and submission ID for retry',
    (tester) async {
      final service = _PhotoUploadService(
        'http://127.0.0.1:9',
        box,
        _MemorySecrets(),
      );
      addTearDown(service.dispose);
      final photo = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAIAAAACACAIAAABMXPacAAABC0lEQVR4nO3TQREAAAjDMPybBhk8mkjYrrO8Gvs7IE0BDmhTgAPaFOCANgU4oE0BDmhTgAPaFOCANgU4oE0BDmhTgAPaFOCANgU4oE0BDmhTgAPaFOCANgU4oE0BDmhTgAPaFOCANgU4oE0BDmhTgAPaFOCANgU4oE0BDmhTgAPaFOCANgU4oE0BDmhTgAPaFOCANgU4oE0BDmhTgAPaFOCANgU4oE0BDmhTgAPaFOCANgU4oE0BDmhTgAPaFOCANgU4oE0BDmhTgAPaFOCANgU4oE0BDmhTgAPaFOCANgU4oE0BDmhTgAPaFOCANgU4oE0BDmhTgAPaFOCANgU4oE0BDmhTgAPaFLC/DpTpSzJeKQ2cAAAAAElFTkSuQmCC',
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MotorPracticePage(
            service: service,
            planId: 'plan',
            exercise: const LibraryExercise(
              id: 'motor-lines',
              name: 'Little paths',
              description: 'Draw lines',
              isMotor: true,
            ),
            photoPicker: _TestPhotoPicker(photo),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose practice photo'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.byType(Image), 200);
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsOneWidget);
      await tester.tap(find.text('Send to my therapist'));
      await tester.pumpAndSettle();
      expect(find.text('Retry later'), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);
      service.reject = false;
      await tester.tap(find.text('Send to my therapist'));
      await tester.pumpAndSettle();
      expect(service.uploads, hasLength(2));
      expect(service.uploads.first.id, service.uploads.last.id);
      expect(service.uploads.last.bytes, photo);
      expect(find.text('Back to today’s practice'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('sign-in checks fields on the page before calling the server', (
    tester,
  ) async {
    final service = ConnectedService(
      'http://127.0.0.1:9',
      box,
      _MemorySecrets(),
    );
    addTearDown(service.dispose);
    await tester.pumpWidget(ConnectedApp(service: service));
    await tester.pumpAndSettle();
    expect(find.text('Welcome back.'), findsOneWidget);

    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a valid email address.'), findsOneWidget);
    expect(find.text('This field is required.'), findsOneWidget);

    await tester.tap(find.text('New here? Create an account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Therapist'));
    await tester.pumpAndSettle();
    expect(find.text('Clinic'), findsOneWidget);
    expect(find.text('Registration number'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
