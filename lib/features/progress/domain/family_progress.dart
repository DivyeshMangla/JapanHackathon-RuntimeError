import 'dart:typed_data';

enum ProgressActivity { words, drawing, expressions }

enum ClinicianAssessment { correct, onTrack, needsPractice, notAssessed }

/// One Monday-to-Sunday week of practice. [score] is the percentage of scored
/// work that met the goal, or null when nothing that week was scored.
class WeeklyProgress {
  const WeeklyProgress({
    required this.weekStart,
    required this.attempts,
    this.score,
  });

  final DateTime weekStart;
  final int attempts;
  final int? score;
}

class ActivityProgress {
  const ActivityProgress({
    required this.activity,
    required this.attempts,
    required this.reviewed,
    required this.clinicianCorrect,
    required this.clinicianNeedsPractice,
    this.clinicianOnTrack = 0,
    this.lastPracticedAt,
    this.quizCorrect = 0,
    this.quizTotal = 0,
    this.quizIndependentCorrect = 0,
    this.quizIndependentTotal = 0,
    this.quizAssistedCorrect = 0,
    this.quizAssistedTotal = 0,
    this.trend = const [],
  });

  final ProgressActivity activity;
  final int attempts;
  final int reviewed;
  final int clinicianCorrect;
  final int clinicianNeedsPractice;
  final int clinicianOnTrack;
  final DateTime? lastPracticedAt;
  final int quizCorrect;
  final int quizTotal;
  final int quizIndependentCorrect;
  final int quizIndependentTotal;
  final int quizAssistedCorrect;
  final int quizAssistedTotal;
  final List<WeeklyProgress> trend;

  List<WeeklyProgress> get scoredWeeks =>
      trend.where((week) => week.score != null).toList();

  int get awaitingReview => attempts - reviewed;
}

class TherapistFeedback {
  const TherapistFeedback({
    required this.id,
    required this.activity,
    required this.text,
    required this.assessment,
    required this.practiceAt,
    this.title,
    this.audioPath,
    this.reviewedAt,
    this.therapistName,
  });

  final String id;
  final ProgressActivity activity;
  final String? title;
  final String text;
  final String? audioPath;
  final ClinicianAssessment assessment;
  final DateTime practiceAt;
  final DateTime? reviewedAt;
  final String? therapistName;
}

class FamilyProgress {
  FamilyProgress({
    required this.patientId,
    required List<ActivityProgress> activities,
    required List<TherapistFeedback> feedback,
  }) : activities = List.unmodifiable(activities),
       feedback = List.unmodifiable(feedback);

  final String patientId;
  final List<ActivityProgress> activities;
  final List<TherapistFeedback> feedback;

  bool get hasPractice => activities.any((activity) => activity.attempts > 0);
}

abstract interface class FamilyProgressRepository {
  Future<FamilyProgress> load(String childId);
  Future<Uint8List> feedbackAudio(String childId, TherapistFeedback feedback);
}
