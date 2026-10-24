import 'dart:convert';
import 'dart:typed_data';

import 'package:intl/intl.dart';

import '../../../core/network/backend_client.dart';
import '../domain/motor.dart';
import '../domain/motor_repository.dart';

final _day = DateFormat('yyyy-MM-dd');

class BackendMotorRepository implements MotorRepository {
  BackendMotorRepository(this._client);

  final BackendClient _client;

  @override
  Future<List<MotorExercise>> exercises() async {
    final config = await _client.get('/config');
    return [
      for (final json in config.objects('exercises'))
        if (json['kind'] == 'motor') _exercise(json),
    ];
  }

  @override
  Future<MotorRecord> recordFor(String childId) async {
    final record = await _client.get('/patients/$childId');
    final plan = record['plan'];
    final consent = record['consent'];
    final motorIds = (await exercises()).map((e) => e.id).toSet();
    final planned = plan is JsonObject
        ? [
            for (final id in plan['exercises']! as List<Object?>)
              if (motorIds.contains(id)) id! as String,
          ]
        : const <String>[];
    return MotorRecord(
      planId: planned.isEmpty ? null : (plan! as JsonObject)['id']! as String,
      exerciseIds: planned,
      submissions: record.objects('motorSubmissions').map(_submission).toList(),
      consented: consent is JsonObject && consent['status'] == 'approved',
    );
  }

  @override
  Future<void> submit({
    required String childId,
    required String planId,
    required String exerciseId,
    required String submissionId,
    required Uint8List photo,
    required DateTime day,
  }) async {
    await _client.post(
      '/patients/$childId/motor-submissions',
      body: {
        'id': submissionId,
        'planId': planId,
        'exerciseId': exerciseId,
        'photo': base64Encode(photo),
        'practiceDay': _day.format(day),
      },
    );
  }

  @override
  Future<void> assign({
    required String childId,
    required String title,
    required List<String> exerciseIds,
  }) async {
    await _client.post(
      '/patients/$childId/plans',
      body: {
        'title': title,
        'exercises': exerciseIds,
        // The service starts drawing practice at one gentle round a day.
        'sessionsPerDay': 1,
        'notes': '',
      },
    );
  }

  @override
  Future<Uint8List> photo(String submissionId) =>
      _client.getBytes('/motor-submissions/$submissionId/photo');

  @override
  Future<void> review(String submissionId, String note) async {
    await _client.post(
      '/motor-submissions/$submissionId/review',
      body: {'note': note},
    );
  }

  @override
  Future<void> retryAnalysis(String submissionId) async {
    await _client.post('/motor-submissions/$submissionId/analyze');
  }

  MotorExercise _exercise(JsonObject json) => MotorExercise(
    id: json['id']! as String,
    name: json['name']! as String,
    description: json['description']! as String,
    minutes: json['minutes'] as int? ?? 1,
    steps: [
      for (final step in json['steps'] as List<Object?>? ?? const [])
        step! as String,
    ],
    strokes: [
      for (final stroke in json['strokes'] as List<Object?>? ?? const [])
        [
          for (final point in stroke! as List<Object?>)
            [
              for (final value in point! as List<Object?>)
                (value! as num).toDouble(),
            ],
        ],
    ],
  );

  MotorSubmission _submission(JsonObject json) {
    final report = json['report'];
    return MotorSubmission(
      id: json['id']! as String,
      exerciseId: json['exercise_id']! as String,
      practiceDay: json['practice_day']! as String,
      status: MotorAnalysisStatus.values.byName(
        json['analysis_status']! as String,
      ),
      createdAt: DateTime.parse(json['created_at']! as String).toLocal(),
      reviewNote: json['review_note'] as String?,
      report: report is JsonObject
          ? MotorReport(
              observations: report['observations']! as String,
              suggestion: report['suggestion']! as String,
              alignment: report['alignment']! as String,
              formation: report['formation']! as String,
              spacing: report['spacing']! as String,
              model: report['model']! as String,
              imageQuality: report['imageQuality']! as String,
              comparison: report['comparison'] as String?,
              expectedResult: report['expectedResult'] as String?,
            )
          : null,
    );
  }
}
