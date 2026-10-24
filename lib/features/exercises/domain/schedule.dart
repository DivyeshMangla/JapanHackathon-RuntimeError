import '../../../core/utils/dates.dart';
import 'exercise.dart';

/// One version of an assignment: a patient, an exercise, the days it is due,
/// and the therapist-set dosage and targets (research doc 7.4).
///
/// Assignments are versioned. Editing one closes the current version the day
/// before and starts a new version today, so every past day is scored
/// against the version that was active on that day.
class Schedule {
  const Schedule({
    required this.id,
    required this.patientId,
    required this.exerciseId,
    required this.weekdays,
    required this.effectiveFrom,
    this.effectiveTo,
    this.sessionsPerDay = 1,
    this.repetitions = 1,
    this.targets = const ExerciseTargets(),
    this.instructions = '',
    this.assignedBy,
  });

  /// Identifies this version, not the assignment as a whole.
  final String id;
  final String patientId;
  final String exerciseId;

  /// [DateTime.monday] (1) through [DateTime.sunday] (7).
  final Set<int> weekdays;

  /// First day this version applies, as a date with no time component.
  final DateTime effectiveFrom;

  /// Last day this version applies (inclusive), or null while current.
  final DateTime? effectiveTo;

  final int sessionsPerDay;
  final int repetitions;
  final ExerciseTargets targets;

  /// The therapist's own instructions for this patient, such as the chosen
  /// syllables or water depth. Empty when none were given.
  final String instructions;

  /// The therapist who set this version.
  final String? assignedBy;

  bool get isCurrent => effectiveTo == null;

  bool isActiveOn(DateTime day) {
    final date = dateOnly(day);
    final end = effectiveTo;
    return !date.isBefore(effectiveFrom) && (end == null || !date.isAfter(end));
  }

  bool isDueOn(DateTime day) =>
      isActiveOn(day) && weekdays.contains(day.weekday);

  Schedule copyWith({
    String? id,
    Set<int>? weekdays,
    DateTime? effectiveFrom,
    DateTime? effectiveTo,
    int? sessionsPerDay,
    int? repetitions,
    ExerciseTargets? targets,
    String? instructions,
    String? assignedBy,
  }) => Schedule(
    id: id ?? this.id,
    patientId: patientId,
    exerciseId: exerciseId,
    weekdays: weekdays ?? this.weekdays,
    effectiveFrom: effectiveFrom ?? this.effectiveFrom,
    effectiveTo: effectiveTo ?? this.effectiveTo,
    sessionsPerDay: sessionsPerDay ?? this.sessionsPerDay,
    repetitions: repetitions ?? this.repetitions,
    targets: targets ?? this.targets,
    instructions: instructions ?? this.instructions,
    assignedBy: assignedBy ?? this.assignedBy,
  );

  Map<String, Object?> toMap() => {
    'id': id,
    'patientId': patientId,
    'exerciseId': exerciseId,
    'weekdays': weekdays.toList()..sort(),
    'effectiveFrom': effectiveFrom.toIso8601String(),
    'effectiveTo': effectiveTo?.toIso8601String(),
    'sessionsPerDay': sessionsPerDay,
    'repetitions': repetitions,
    'targets': targets.toMap(),
    'instructions': instructions,
    'assignedBy': assignedBy,
  };

  factory Schedule.fromMap(Map<dynamic, dynamic> map) {
    final to = map['effectiveTo'] as String?;
    final targets = map['targets'] as Map<dynamic, dynamic>?;
    return Schedule(
      id: map['id'] as String,
      patientId: map['patientId'] as String,
      exerciseId: map['exerciseId'] as String,
      weekdays: (map['weekdays'] as List<dynamic>).cast<int>().toSet(),
      // Records written before versioning stored "startDate".
      effectiveFrom: DateTime.parse(
        (map['effectiveFrom'] ?? map['startDate']) as String,
      ),
      effectiveTo: to == null ? null : DateTime.parse(to),
      sessionsPerDay: map['sessionsPerDay'] as int? ?? 1,
      repetitions: map['repetitions'] as int? ?? 1,
      targets: targets == null
          ? const ExerciseTargets()
          : ExerciseTargets.fromMap(targets),
      instructions: map['instructions'] as String? ?? '',
      assignedBy: map['assignedBy'] as String?,
    );
  }
}

/// Records to write and version ids to delete for one assignment change.
typedef ScheduleChange = ({List<Schedule> save, List<String> delete});

/// Versioning rules for assignment edits.
abstract final class ScheduleVersioning {
  /// Applies [revised] dosage from [today] on. Past days keep [current]:
  /// it is closed yesterday and [revised] starts today under [newId]. A
  /// version that only started today is replaced outright.
  static ScheduleChange revise({
    required Schedule current,
    required Schedule revised,
    required DateTime today,
    required String newId,
  }) {
    final day = dateOnly(today);
    if (!current.effectiveFrom.isBefore(day)) {
      return (
        save: [revised.copyWith(id: current.id, effectiveFrom: day)],
        delete: const [],
      );
    }
    return (
      save: [
        current.copyWith(effectiveTo: addDays(day, -1)),
        revised.copyWith(id: newId, effectiveFrom: day),
      ],
      delete: const [],
    );
  }

  /// Ends an assignment so it is no longer due from [today]. History before
  /// today is kept; a version that only started today is deleted.
  static ScheduleChange end({
    required Schedule current,
    required DateTime today,
  }) {
    final day = dateOnly(today);
    if (!current.effectiveFrom.isBefore(day)) {
      return (save: const [], delete: [current.id]);
    }
    return (
      save: [current.copyWith(effectiveTo: addDays(day, -1))],
      delete: const [],
    );
  }
}
