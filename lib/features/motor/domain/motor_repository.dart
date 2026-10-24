import 'dart:typed_data';

import 'motor.dart';

abstract interface class MotorRepository {
  Future<List<MotorExercise>> exercises();

  Future<MotorRecord> recordFor(String childId);

  /// Sends a photo of today's [exerciseId]. A repeated [submissionId] is
  /// ignored by the service, so a retry never counts twice.
  Future<void> submit({
    required String childId,
    required String planId,
    required String exerciseId,
    required String submissionId,
    required Uint8List photo,
    required DateTime day,
  });

  /// Replaces the child's drawing plan with [exerciseIds].
  Future<void> assign({
    required String childId,
    required String title,
    required List<String> exerciseIds,
  });

  Future<Uint8List> photo(String submissionId);

  Future<void> review(String submissionId, String note);

  /// Asks the local vision model to try a photo again.
  Future<void> retryAnalysis(String submissionId);
}
