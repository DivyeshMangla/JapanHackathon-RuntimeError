import 'dart:convert';
import 'dart:typed_data';

import '../../../core/errors/app_failure.dart';
import '../../../core/errors/guard.dart';
import '../../../core/network/backend_client.dart';
import '../domain/family_progress.dart';

class BackendFamilyProgressRepository implements FamilyProgressRepository {
  const BackendFamilyProgressRepository(this._client);

  final BackendClient _client;

  @override
  Future<FamilyProgress> load(String childId) => guard(() async {
    final json = await _client.get(
      '/patients/${Uri.encodeComponent(childId)}/family-progress',
    );
    final patientId = json['patientId']! as String;
    if (patientId != childId) {
      throw const NetworkFailure(NetworkProblem.badResponse);
    }
    return FamilyProgress(
      patientId: patientId,
      activities: json.objects('activities').map(_activity).toList(),
      feedback: json.objects('feedback').map(_feedback).toList(),
    );
  }, (_) => const NetworkFailure(NetworkProblem.badResponse));

  @override
  Future<Uint8List> feedbackAudio(String childId, TherapistFeedback feedback) =>
      guard(() async {
        final path = feedback.audioPath;
        final expected =
            '/useful-words/patients/${Uri.encodeComponent(childId)}/attempts/';
        if (path == null ||
            !path.startsWith(expected) ||
            !path.endsWith('/feedback')) {
          throw const NetworkFailure(NetworkProblem.badResponse);
        }
        final json = await _client.get(path);
        return base64Decode(json['audio']! as String);
      }, (_) => const NetworkFailure(NetworkProblem.badResponse));

  ActivityProgress _activity(JsonObject json) => ActivityProgress(
    activity: ProgressActivity.values.byName(json['kind']! as String),
    attempts: json['attempts']! as int,
    reviewed: json['reviewed']! as int,
    clinicianCorrect: json['clinicianCorrect'] as int? ?? 0,
    clinicianNeedsPractice: json['clinicianNeedsPractice'] as int? ?? 0,
    clinicianOnTrack: json['clinicianOnTrack'] as int? ?? 0,
    lastPracticedAt: _date(json['lastPracticedAt']),
    quizCorrect: json['quizCorrect'] as int? ?? 0,
    quizTotal: json['quizTotal'] as int? ?? 0,
    quizIndependentCorrect: json['quizIndependentCorrect'] as int? ?? 0,
    quizIndependentTotal: json['quizIndependentTotal'] as int? ?? 0,
    quizAssistedCorrect: json['quizAssistedCorrect'] as int? ?? 0,
    quizAssistedTotal: json['quizAssistedTotal'] as int? ?? 0,
  );

  TherapistFeedback _feedback(JsonObject json) => TherapistFeedback(
    id: json['id']! as String,
    activity: ProgressActivity.values.byName(json['kind']! as String),
    title: json['title'] as String?,
    text: json['text']! as String,
    audioPath: json['audioPath'] as String?,
    assessment: switch (json['assessment']) {
      'correct' => ClinicianAssessment.correct,
      'on_track' => ClinicianAssessment.onTrack,
      'needs_practice' => ClinicianAssessment.needsPractice,
      _ => ClinicianAssessment.notAssessed,
    },
    practiceAt: _date(json['practiceAt'])!,
    reviewedAt: _date(json['reviewedAt']),
    therapistName: json['therapistName'] as String?,
  );

  DateTime? _date(Object? value) =>
      value == null ? null : DateTime.parse(value as String).toLocal();
}
