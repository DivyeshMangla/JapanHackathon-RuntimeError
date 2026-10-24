import 'package:flutter/widgets.dart';

import '../../features/audit/domain/access_log.dart';
import '../../features/capture_quality/domain/take_quality.dart';
import '../../features/recordings/domain/recording.dart';
import '../../features/usage/domain/usage_event.dart';
import '../../l10n/generated/app_localizations.dart';
import '../errors/app_failure.dart';

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

/// Staff-facing text for audit enums.
extension StudyText on AppLocalizations {
  String accessActionLabel(AccessAction action) => switch (action) {
    AccessAction.playback => accessPlayback,
    AccessAction.export => accessExport,
  };
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
    },
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
