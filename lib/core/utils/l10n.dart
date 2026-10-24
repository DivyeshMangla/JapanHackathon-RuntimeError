import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import '../../features/audit/domain/access_log.dart';
import '../../features/capture_quality/domain/take_quality.dart';
import '../../features/exercises/domain/exercise.dart';
import '../../features/exercises/domain/exercise_demo.dart';
import '../../features/exercises/domain/voice_use_entry.dart';
import '../../features/recordings/domain/recording.dart';
import '../../features/study/domain/participant_status.dart';
import '../../features/usage/domain/usage_event.dart';
import '../../l10n/generated/app_localizations.dart';
import '../errors/app_failure.dart';
import 'dates.dart';

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
    MediaFailure(:final problem) => switch (problem) {
      MediaProblem.unavailable => failureMediaUnavailable,
      MediaProblem.tooLarge => failureMediaTooLarge,
    },
    NetworkFailure(:final problem, :final serverMessage) => switch (problem) {
      NetworkProblem.offline => failureOffline,
      NetworkProblem.timeout => failureTimeout,
      NetworkProblem.badResponse => failureBadResponse,
      NetworkProblem.sessionEnded => failureSessionEnded,
      NetworkProblem.rejected => serverMessage ?? failureRejected,
    },
    InvalidInputFailure(:final problem) => switch (problem) {
      InputProblem.emailTaken => emailTaken,
      InputProblem.therapistRequired => chooseTherapist,
      InputProblem.exerciseNotApproved => exerciseNotApproved,
      InputProblem.consentRequired => consentRequired,
      InputProblem.instructionsRequired => instructionsRequired,
    },
  };
}

/// Voice-use diary text.
extension DiaryText on AppLocalizations {
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
}

/// Staff-facing text for the usage log.
extension UsageLogText on AppLocalizations {
  String usageLabel(UsageAction action) => switch (action) {
    UsageAction.signIn => usageSignIn,
    UsageAction.signOut => usageSignOut,
    UsageAction.exerciseOpened => usageExerciseOpened,
    UsageAction.educationOpened => usageEducationOpened,
    UsageAction.sessionMarked => usageSessionMarked,
    UsageAction.sessionUndone => usageSessionUndone,
    UsageAction.recordingSaved => usageRecordingSaved,
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
