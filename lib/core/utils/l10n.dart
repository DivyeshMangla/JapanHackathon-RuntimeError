import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import '../../features/audit/domain/access_log.dart';
import '../../features/capture_quality/domain/take_quality.dart';
import '../../features/education/domain/education_topic.dart';
import '../../features/exercises/domain/exercise.dart';
import '../../features/exercises/domain/exercise_demo.dart';
import '../../features/exercises/domain/voice_use_entry.dart';
import '../../features/questionnaires/domain/questionnaire.dart';
import '../../features/questionnaires/domain/study_tasks.dart';
import '../../features/recordings/domain/recording.dart';
import '../../features/study/domain/assessment_checklist.dart';
import '../../features/study/domain/monitoring_entry.dart';
import '../../features/study/domain/participant_record.dart';
import '../../features/study/domain/participant_status.dart';
import '../../features/study/domain/study_period.dart';
import '../../features/usage/domain/usage_event.dart';
import '../../l10n/generated/app_localizations.dart';
import '../errors/app_failure.dart';
import 'dates.dart';
import 'formatting.dart';

export '../../l10n/generated/app_localizations.dart';

extension AppLocalizationsContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

/// Patient-facing text for domain enums, which stay language-neutral.
extension RecordingText on AppLocalizations {
  String taskLabel(RecordingTask task) => switch (task) {
    RecordingTask.sustainedPhonation => taskSustainedPhonation,
    RecordingTask.readingPassage => taskReadingPassage,
    RecordingTask.spontaneousSpeech => taskSpontaneousSpeech,
    RecordingTask.sustainedA => taskSustainedA,
    RecordingTask.maximumA => taskMaximumA,
    RecordingTask.sustainedS => taskSustainedS,
    RecordingTask.sustainedZ => taskSustainedZ,
    RecordingTask.vowelA => taskVowelA,
    RecordingTask.vowelI => taskVowelI,
    RecordingTask.vowelU => taskVowelU,
    RecordingTask.pitchGlide => taskPitchGlide,
  };

  String taskInstructions(RecordingTask task) => switch (task) {
    RecordingTask.sustainedPhonation => taskSustainedPhonationHow,
    RecordingTask.readingPassage => taskReadingPassageHow,
    RecordingTask.spontaneousSpeech => taskSpontaneousSpeechHow,
    RecordingTask.sustainedA => taskSustainedAHow,
    RecordingTask.maximumA => taskMaximumAHow,
    RecordingTask.sustainedS => taskSustainedSHow,
    RecordingTask.sustainedZ => taskSustainedZHow,
    RecordingTask.vowelA => taskVowelAHow,
    RecordingTask.vowelI => taskVowelIHow,
    RecordingTask.vowelU => taskVowelUHow,
    RecordingTask.pitchGlide => taskPitchGlideHow,
  };

  String takeIssueText(TakeIssue issue) => switch (issue) {
    TakeIssue.noVoice => takeIssueNoVoice,
    TakeIssue.noisy => takeIssueNoisy,
    TakeIssue.clipped => takeIssueClipped,
    TakeIssue.moved => takeIssueMoved,
  };

  String kindLabel(RecordingKind kind) => switch (kind) {
    RecordingKind.practice => kindPractice,
    RecordingKind.probe => kindProbe,
  };

  String typeLabel(RecordingType type) => switch (type) {
    RecordingType.baseline => typeBaseline,
    RecordingType.followUp => typeFollowUp,
    RecordingType.homePractice => typeHomePractice,
  };

  String greeting(DateTime now, String name) => switch (now.hour) {
    < 12 => greetingMorning(name),
    < 18 => greetingAfternoon(name),
    _ => greetingEvening(name),
  };

  String analysisLabel(AnalysisStatus status) => switch (status) {
    AnalysisStatus.pending => analysisPending,
  };
}

/// Staff-facing text for study, library and audit enums.
extension StudyText on AppLocalizations {
  String statusLabel(ParticipantStatus status) => switch (status) {
    ParticipantStatus.onTrack => statusOnTrack,
    ParticipantStatus.plateau => statusPlateau,
    ParticipantStatus.adherenceProblem => statusAdherenceProblem,
    ParticipantStatus.needsReview => statusNeedsReview,
    ParticipantStatus.improvingDespiteLowPractice => statusImproving,
    ParticipantStatus.awaitingProbe => statusAwaitingProbe,
  };

  String statusAction(ParticipantStatus status) => switch (status) {
    ParticipantStatus.onTrack => statusOnTrackAction,
    ParticipantStatus.plateau => statusPlateauAction,
    ParticipantStatus.adherenceProblem => statusAdherenceProblemAction,
    ParticipantStatus.needsReview => statusNeedsReviewAction,
    ParticipantStatus.improvingDespiteLowPractice => statusImprovingAction,
    ParticipantStatus.awaitingProbe => statusAwaitingProbeAction,
  };

  String exerciseStatusLabel(ExerciseStatus status) => switch (status) {
    ExerciseStatus.pendingApproval => exerciseStatusPending,
    ExerciseStatus.approved => exerciseStatusApproved,
    ExerciseStatus.archived => exerciseStatusArchived,
  };

  String verificationLabel(VerificationType type) => switch (type) {
    VerificationType.sustained => verifySustained,
    VerificationType.glide => verifyGlide,
    VerificationType.notes => verifyNotes,
    VerificationType.loudness => verifyLoudness,
    VerificationType.checklist => verifyChecklist,
    VerificationType.voiceDiary => verifyVoiceDiary,
  };

  String accessActionLabel(AccessAction action) => switch (action) {
    AccessAction.playback => accessPlayback,
    AccessAction.export => accessExport,
  };

  /// "Every day", "Weekdays", or short day names such as "Mon, Wed, Fri".
  String describeWeekdays(Set<int> weekdays) {
    if (weekdays.length == 7) return everyDay;
    if (weekdays.length == 5 && weekdays.every((d) => d <= 5)) {
      return weekdaysOnly;
    }
    return (weekdays.toList()..sort()).map(shortWeekday).join(', ');
  }

  /// Short localized day name; 1 is Monday.
  String shortWeekday(int weekday) =>
      DateFormat.E(localeName).format(DateTime(2024, 1, weekday));

  String lastActive(DateTime? lastCompletedAt) {
    if (lastCompletedAt == null) return lastExerciseNone;
    final days = dateOnly(
      DateTime.now(),
    ).difference(dateOnly(lastCompletedAt)).inDays;
    return switch (days) {
      0 => lastExerciseToday,
      1 => lastExerciseYesterday,
      _ => lastExerciseDaysAgo(days),
    };
  }
}

/// User-facing messages for typed failures.
extension FailureText on AppLocalizations {
  String failureMessage(AppFailure failure) => switch (failure) {
    StorageFailure() => failureStorage,
    RecordingFailure() => failureRecording,
    PlaybackFailure() => failurePlayback,
    ReminderFailure() => failureReminder,
    ExportFailure() => exportFailed,
    SensorFailure() => failureSensor,
    InvalidInputFailure(:final problem) => switch (problem) {
      InputProblem.emailTaken => emailTaken,
      InputProblem.therapistRequired => chooseTherapist,
      InputProblem.exerciseNotApproved => exerciseNotApproved,
      InputProblem.consentRequired => consentRequired,
      InputProblem.instructionsRequired => instructionsRequired,
    },
  };
}

/// Patient-facing education and questionnaire text.
extension EducationText on AppLocalizations {
  String topicTitle(EducationTopic topic) => switch (topic) {
    EducationTopic.usingTheApp => learnAppTitle,
    EducationTopic.homePractice => learnPracticeTitle,
    EducationTopic.voiceCare => learnVoiceCareTitle,
    EducationTopic.aboutStudy => learnStudyTitle,
  };

  String topicSummary(EducationTopic topic) => switch (topic) {
    EducationTopic.usingTheApp => learnAppSummary,
    EducationTopic.homePractice => learnPracticeSummary,
    EducationTopic.voiceCare => learnVoiceCareSummary,
    EducationTopic.aboutStudy => learnStudySummary,
  };

  List<String> topicPoints(EducationTopic topic) => switch (topic) {
    EducationTopic.usingTheApp => [
      learnApp1,
      learnApp2,
      learnApp3,
      learnApp4,
      learnApp5,
      learnApp6,
      learnApp7,
    ],
    EducationTopic.homePractice => [
      learnPractice1,
      learnPractice2,
      learnPractice3,
      learnPractice4,
      learnPractice5,
    ],
    EducationTopic.voiceCare => [
      learnVoiceCare1,
      learnVoiceCare2,
      learnVoiceCare3,
      learnVoiceCare4,
      learnVoiceCare5,
      learnVoiceCare6,
      learnVoiceCare7,
    ],
    EducationTopic.aboutStudy => [
      learnStudy1,
      learnStudy2,
      learnStudy3,
      learnStudy4,
      learnStudy5,
      learnStudy6,
    ],
  };

  /// Closing note shown under a topic's points, if it has one.
  String? topicNote(EducationTopic topic) => switch (topic) {
    EducationTopic.voiceCare => learnVoiceCareNote,
    EducationTopic.homePractice => learnPracticeNote,
    _ => null,
  };

  String taskTitle(StudyTask task) => switch (task.kind) {
    StudyTaskKind.baselineSelfReport => taskBaselineReport,
    StudyTaskKind.weeklySelfReport => taskWeeklyReport(task.week),
    StudyTaskKind.usability => taskUsability,
    StudyTaskKind.feedback => taskFeedback,
  };

  String taskDuration(StudyTaskKind kind) => switch (kind) {
    StudyTaskKind.baselineSelfReport ||
    StudyTaskKind.weeklySelfReport => taskOneMinute,
    StudyTaskKind.usability => taskTwoMinutes,
    StudyTaskKind.feedback => taskFiveMinutes,
  };

  String barrierLabel(PracticeBarrier barrier) => switch (barrier) {
    PracticeBarrier.none => barrierNone,
    PracticeBarrier.forgot => barrierForgot,
    PracticeBarrier.noTime => barrierNoTime,
    PracticeBarrier.voiceDiscomfort => barrierDiscomfort,
    PracticeBarrier.unsureHow => barrierUnsure,
    PracticeBarrier.feltBetter => barrierFeltBetter,
    PracticeBarrier.other => barrierOther,
  };

  /// The ten System Usability Scale statements, in order.
  List<String> get susItems => [
    sus1,
    sus2,
    sus3,
    sus4,
    sus5,
    sus6,
    sus7,
    sus8,
    sus9,
    sus10,
  ];

  String satisfactionStatement(SatisfactionItem item) => switch (item) {
    SatisfactionItem.remindersHelpful => feedbackReminders,
    SatisfactionItem.scheduleClear => feedbackSchedule,
    SatisfactionItem.instructionsClear => feedbackInstructions,
    SatisfactionItem.checklistEasy => feedbackChecklist,
    SatisfactionItem.progressMotivating => feedbackProgress,
    SatisfactionItem.recordingEasy => feedbackRecording,
    SatisfactionItem.privacyComfortable => feedbackPrivacy,
    SatisfactionItem.overallSatisfied => feedbackOverall,
    SatisfactionItem.wouldContinue => feedbackContinue,
  };

  String speakingTimeLabel(SpeakingTime time) => switch (time) {
    SpeakingTime.underOneHour => speakingUnderOne,
    SpeakingTime.oneToTwoHours => speakingOneToTwo,
    SpeakingTime.twoToFourHours => speakingTwoToFour,
    SpeakingTime.fourToSixHours => speakingFourToSix,
    SpeakingTime.overSixHours => speakingOverSix,
  };

  String situationLabel(VoiceSituation situation) => switch (situation) {
    VoiceSituation.phoneCalls => situationPhone,
    VoiceSituation.noisyPlaces => situationNoise,
    VoiceSituation.workSpeaking => situationWork,
    VoiceSituation.longConversations => situationConversation,
    VoiceSituation.singing => situationSinging,
    VoiceSituation.other => situationOther,
  };

  /// Label for a 1-5 agreement answer.
  String agreement(int value) => switch (value) {
    1 => agreeStronglyDisagree,
    2 => agreeDisagree,
    3 => agreeNeutral,
    4 => agreeAgree,
    _ => agreeStronglyAgree,
  };
}

/// Staff-facing text for the study record, monitoring and usage log.
extension StudyRecordText on AppLocalizations {
  String genderLabel(Gender gender) => switch (gender) {
    Gender.female => genderFemale,
    Gender.male => genderMale,
    Gender.other => genderOther,
    Gender.preferNotToSay => genderUndisclosed,
  };

  String educationLabel(EducationLevel level) => switch (level) {
    EducationLevel.noFormal => educationNone,
    EducationLevel.primary => educationPrimary,
    EducationLevel.secondary => educationSecondary,
    EducationLevel.higherSecondary => educationHigherSecondary,
    EducationLevel.graduate => educationGraduate,
    EducationLevel.postgraduate => educationPostgraduate,
  };

  String voiceUseLabel(VoiceUseLevel level) => switch (level) {
    VoiceUseLevel.eliteVocal => voiceUseElite,
    VoiceUseLevel.professionalVocal => voiceUseProfessional,
    VoiceUseLevel.nonVocalProfessional => voiceUseNonVocalProfessional,
    VoiceUseLevel.nonVocalNonProfessional => voiceUseNonVocal,
  };

  String smokingLabel(SmokingStatus status) => switch (status) {
    SmokingStatus.never => smokingNever,
    SmokingStatus.former => smokingFormer,
    SmokingStatus.current => smokingCurrent,
  };

  String ratingLabel(MonitoringRating rating) => switch (rating) {
    MonitoringRating.fully => ratingFully,
    MonitoringRating.mostly => ratingMostly,
    MonitoringRating.partly => ratingPartly,
    MonitoringRating.notAtAll => ratingNotAtAll,
  };

  String baselineItemLabel(BaselineItem item) => switch (item) {
    BaselineItem.consent => baselineConsent,
    BaselineItem.demographics => baselineDemographics,
    BaselineItem.clinical => baselineClinical,
    BaselineItem.baselineAdherence => baselineAdherence,
    BaselineItem.orientation => baselineOrientation,
    BaselineItem.baselineRecording => baselineRecording,
  };

  String followUpItemLabel(FollowUpItem item) => switch (item) {
    FollowUpItem.adherence => followUpAdherence,
    FollowUpItem.compliance => followUpCompliance,
    FollowUpItem.usability => followUpUsability,
    FollowUpItem.feedback => followUpFeedback,
    FollowUpItem.postRecording => followUpRecording,
  };

  /// Where the participant is in the study as of [now].
  String studyPhase(
    ParticipantRecord record,
    StudyPeriod period,
    DateTime now,
  ) {
    final withdrawal = record.withdrawnOn;
    if (withdrawal != null) return withdrawnOn(formatFullDate(withdrawal));
    if (!period.hasStarted(now)) {
      return phaseNotStarted(formatFullDate(period.start));
    }
    if (period.hasEnded(now)) return phaseEnded(formatFullDate(period.end));
    return phaseWeek(period.weekOf(now)!, period.weeks);
  }

  String usageLabel(UsageAction action) => switch (action) {
    UsageAction.signIn => usageSignIn,
    UsageAction.signOut => usageSignOut,
    UsageAction.exerciseOpened => usageExerciseOpened,
    UsageAction.educationOpened => usageEducationOpened,
    UsageAction.sessionMarked => usageSessionMarked,
    UsageAction.sessionUndone => usageSessionUndone,
    UsageAction.recordingSaved => usageRecordingSaved,
    UsageAction.questionnaireSubmitted => usageQuestionnaireSubmitted,
    UsageAction.remindersChanged => usageRemindersChanged,
  };
}

/// Cues for guided exercise animations.
extension ExerciseDemoText on AppLocalizations {
  String demoCueLabel(DemoCue cue) => switch (cue) {
    DemoCue.breatheIn => demoCueBreatheIn,
    DemoCue.breatheOut => demoCueBreatheOut,
  };

  String demoCueHint(DemoCue cue) => switch (cue) {
    DemoCue.breatheIn => demoCueBreatheInHint,
    DemoCue.breatheOut => demoCueBreatheOutHint,
  };
}
