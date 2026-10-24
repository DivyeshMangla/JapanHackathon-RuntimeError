import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/motor_repository_providers.dart';
import '../../domain/motor.dart';

final motorExercisesProvider = FutureProvider<List<MotorExercise>>(
  (ref) => ref.watch(motorRepositoryProvider).exercises(),
);

final motorRecordProvider = FutureProvider.family<MotorRecord, String>(
  (ref, childId) => ref.watch(motorRepositoryProvider).recordFor(childId),
);

final motorActionsProvider = Provider<MotorActions>(MotorActions.new);

/// Drawing practice changes. Each reloads the child's record afterwards so
/// screens show what the care service stored.
class MotorActions {
  MotorActions(this._ref);

  final Ref _ref;

  Future<void> submit({
    required String childId,
    required String planId,
    required String exerciseId,
    required String submissionId,
    required Uint8List photo,
  }) async {
    await _ref
        .read(motorRepositoryProvider)
        .submit(
          childId: childId,
          planId: planId,
          exerciseId: exerciseId,
          submissionId: submissionId,
          photo: photo,
          day: DateTime.now(),
        );
    _ref.invalidate(motorRecordProvider(childId));
  }

  Future<void> assign({
    required String childId,
    required String title,
    required List<String> exerciseIds,
  }) async {
    await _ref
        .read(motorRepositoryProvider)
        .assign(childId: childId, title: title, exerciseIds: exerciseIds);
    _ref.invalidate(motorRecordProvider(childId));
  }

  Future<void> review(String childId, String submissionId, String note) async {
    await _ref.read(motorRepositoryProvider).review(submissionId, note);
    _ref.invalidate(motorRecordProvider(childId));
  }

  Future<void> retryAnalysis(String childId, String submissionId) async {
    await _ref.read(motorRepositoryProvider).retryAnalysis(submissionId);
    _ref.invalidate(motorRecordProvider(childId));
  }
}
