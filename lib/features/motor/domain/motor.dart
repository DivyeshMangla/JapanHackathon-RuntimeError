/// A short drawing task with an animated guide. The catalogue ships with
/// the care service; the treating therapist chooses which a child practises.
class MotorExercise {
  const MotorExercise({
    required this.id,
    required this.name,
    required this.description,
    required this.minutes,
    required this.steps,
    required this.strokes,
  });

  final String id;
  final String name;
  final String description;
  final int minutes;
  final List<String> steps;

  /// Guide strokes as points normalised to a 3:2 board.
  final List<List<List<double>>> strokes;
}

enum MotorAnalysisStatus { pending, processing, ready, unavailable, declined }

/// The local vision model's description of a photo. It is a suggestion for
/// the therapist, never shown to the child or parent.
class MotorReport {
  const MotorReport({
    required this.observations,
    required this.suggestion,
    required this.alignment,
    required this.formation,
    required this.spacing,
    required this.model,
    required this.imageQuality,
    this.comparison,
    this.expectedResult,
  });

  final String observations;
  final String suggestion;
  final String alignment;
  final String formation;
  final String spacing;
  final String model;
  final String imageQuality;
  final String? comparison;
  final String? expectedResult;
}

/// One photo of a child's drawing.
class MotorSubmission {
  const MotorSubmission({
    required this.id,
    required this.exerciseId,
    required this.practiceDay,
    required this.status,
    required this.createdAt,
    this.report,
    this.reviewNote,
  });

  final String id;
  final String exerciseId;

  /// The day practised, as yyyy-MM-dd.
  final String practiceDay;
  final MotorAnalysisStatus status;
  final DateTime createdAt;
  final MotorReport? report;
  final String? reviewNote;
}

/// A child's drawing practice: the plan their therapist set and the photos
/// sent so far, newest first.
class MotorRecord {
  const MotorRecord({
    required this.planId,
    required this.exerciseIds,
    required this.submissions,
    required this.consented,
  });

  /// Null until the therapist assigns drawing practice.
  final String? planId;
  final List<String> exerciseIds;
  final List<MotorSubmission> submissions;

  /// Whether a parent has signed consent, without which nothing uploads.
  final bool consented;

  /// The planned tasks from [catalogue], in the order the therapist set.
  List<MotorExercise> plannedFrom(List<MotorExercise> catalogue) => [
    for (final id in exerciseIds)
      ...catalogue.where((exercise) => exercise.id == id),
  ];

  Set<String> doneOn(String day) => {
    for (final submission in submissions)
      if (submission.practiceDay == day) submission.exerciseId,
  };
}
