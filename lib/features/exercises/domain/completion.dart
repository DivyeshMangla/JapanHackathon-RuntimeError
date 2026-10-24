/// A patient marking an exercise done on a given day.
class Completion {
  const Completion({
    required this.id,
    required this.patientId,
    required this.exerciseId,
    required this.day,
    required this.completedAt,
  });

  final String id;
  final String patientId;
  final String exerciseId;

  /// The calendar day the completion counts toward, with no time component.
  final DateTime day;
  final DateTime completedAt;

  Map<String, Object?> toMap() => {
    'id': id,
    'patientId': patientId,
    'exerciseId': exerciseId,
    'day': day.toIso8601String(),
    'completedAt': completedAt.toIso8601String(),
  };

  factory Completion.fromMap(Map<dynamic, dynamic> map) => Completion(
    id: map['id'] as String,
    patientId: map['patientId'] as String,
    exerciseId: map['exerciseId'] as String,
    day: DateTime.parse(map['day'] as String),
    completedAt: DateTime.parse(map['completedAt'] as String),
  );
}
