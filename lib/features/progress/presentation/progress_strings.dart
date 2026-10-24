import '../domain/family_progress.dart';

abstract final class ProgressStrings {
  static const title = 'Progress and therapist feedback';
  static const childTitle = 'A message from your therapist';
  static const childIntro =
      'Read or listen with your grown-up, then try your therapist’s ideas together.';
  static const participation = 'Practice completed';
  static const participationHelp =
      'Practice counts show participation. Your therapist’s assessment shows what to work on next.';
  static const feedback = 'Your therapist’s guidance';
  static const noFeedbackTitle = 'Waiting for your therapist';
  static const noFeedbackBody =
      'When your therapist reviews your practice and shares guidance, it will appear here. You can keep practising your assigned activities.';
  static const noPracticeTitle = 'Your progress starts here';
  static const noPracticeBody =
      'Try an activity chosen by your therapist. Your completed practice and therapist feedback will appear here.';
  static const noAssessment = 'Your therapist has not assessed accuracy yet.';
  static const quizHelp =
      'Picture-choice accuracy for these practice cards; your therapist will help apply this to everyday situations.';
  static const retry = 'Try again';
  static const refresh = 'Refresh progress';
  static const listen = 'Listen to your therapist';
  static const stop = 'Stop listening';
  static const loadingAudio = 'Loading message…';
  static const therapist = 'Your therapist';
  static const correct = 'Therapist assessment: correct';
  static const onTrack = 'Therapist assessment: on track';
  static const needsPractice = 'Therapist assessment: keep practising';

  static String activity(ProgressActivity value) => switch (value) {
    ProgressActivity.words => 'Say a Word',
    ProgressActivity.drawing => 'Drawing',
    ProgressActivity.expressions => 'Expressions and feelings',
  };

  static String counts(ActivityProgress value) =>
      '${value.attempts} submitted · ${value.reviewed} reviewed · ${value.awaitingReview} awaiting review';
  static String assessmentCounts(ActivityProgress value) =>
      value.activity == ProgressActivity.drawing
      ? 'Therapist assessment: ${value.clinicianOnTrack} on track · ${value.clinicianNeedsPractice} to practise'
      : 'Therapist assessment: ${value.clinicianCorrect} correct · ${value.clinicianNeedsPractice} to practise';
  static String quizCounts(ActivityProgress value) =>
      'Picture choices: ${value.quizCorrect} of ${value.quizTotal} correct (${(100 * value.quizCorrect / value.quizTotal).round()}%)';
  static String practiced(String date) => 'Last practice: $date';
  static String independentChoices(ActivityProgress value) =>
      'Without help: ${value.quizIndependentCorrect} of ${value.quizIndependentTotal} correct';
  static String assistedChoices(ActivityProgress value) =>
      'With adult help: ${value.quizAssistedCorrect} of ${value.quizAssistedTotal} correct';
  static String reviewed(String name, String date) => '$name · reviewed $date';
  static String practiceDate(String date) => 'Practice sent $date';
}
