/// A therapist's judgement on one aspect of home practice.
enum MonitoringRating { fully, mostly, partly, notAtAll }

/// One weekly Adherence and Compliance Monitoring Form, filled in by the
/// therapist from their contact with the participant. It sits beside the
/// application log and the participant's self-report, never replacing them.
class MonitoringEntry {
  const MonitoringEntry({
    required this.id,
    required this.patientId,
    required this.therapistId,
    required this.week,
    required this.recordedAt,
    required this.practice,
    required this.schedule,
    required this.technique,
    this.barriers = '',
    this.notes = '',
  });

  final String id;
  final String patientId;
  final String therapistId;

  /// 1-based study week the form describes.
  final int week;
  final DateTime recordedAt;

  /// Did the participant complete the prescribed exercises?
  final MonitoringRating practice;

  /// Did they keep to the recommended frequency and schedule?
  final MonitoringRating schedule;

  /// Were the exercises performed as instructed when reviewed in clinic?
  final MonitoringRating technique;
  final String barriers;
  final String notes;

  Map<String, Object?> toMap() => {
    'id': id,
    'patientId': patientId,
    'therapistId': therapistId,
    'week': week,
    'recordedAt': recordedAt.toIso8601String(),
    'practice': practice.name,
    'schedule': schedule.name,
    'technique': technique.name,
    'barriers': barriers,
    'notes': notes,
  };

  factory MonitoringEntry.fromMap(Map<dynamic, dynamic> map) {
    MonitoringRating rating(String key) =>
        MonitoringRating.values.byName(map[key] as String);
    return MonitoringEntry(
      id: map['id'] as String,
      patientId: map['patientId'] as String,
      therapistId: map['therapistId'] as String,
      week: map['week'] as int,
      recordedAt: DateTime.parse(map['recordedAt'] as String),
      practice: rating('practice'),
      schedule: rating('schedule'),
      technique: rating('technique'),
      barriers: map['barriers'] as String? ?? '',
      notes: map['notes'] as String? ?? '',
    );
  }
}

abstract interface class MonitoringRepository {
  /// Ordered by week, then by when they were recorded.
  Future<List<MonitoringEntry>> forPatient(String patientId);

  Future<List<MonitoringEntry>> all();

  Future<void> save(MonitoringEntry entry);
}
