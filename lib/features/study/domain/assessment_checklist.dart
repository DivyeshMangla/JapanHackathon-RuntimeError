import '../../../core/utils/dates.dart';
import '../../questionnaires/domain/questionnaire.dart';
import '../../recordings/domain/recording.dart';
import 'intervention_outcome.dart';
import 'participant_record.dart';

/// Baseline assessment steps from the protocol.
enum BaselineItem {
  consent,
  demographics,
  clinical,
  baselineAdherence,
  orientation,
  baselineRecording,
}

/// Follow-up assessment steps at the end of the intervention.
enum FollowUpItem { adherence, compliance, usability, feedback, postRecording }

/// Which assessment steps are complete for one participant.
abstract final class AssessmentChecklist {
  static Map<BaselineItem, bool> baseline({
    required ParticipantRecord record,
    required QuestionnaireHistory questionnaires,
    required List<Recording> recordings,
  }) => {
    BaselineItem.consent: record.hasConsent,
    BaselineItem.demographics: record.demographics != null,
    BaselineItem.clinical: record.clinical != null,
    BaselineItem.baselineAdherence: questionnaires.baseline != null,
    BaselineItem.orientation: record.orientationOn != null,
    BaselineItem.baselineRecording: recordings.any(
      (r) => r.kind == RecordingKind.probe && r.type == RecordingType.baseline,
    ),
  };

  /// Adherence and compliance are complete once every intervention day has
  /// been scored. The post-intervention recording counts from the last
  /// intervention day on.
  static Map<FollowUpItem, bool> followUp({
    required InterventionOutcome outcome,
    required QuestionnaireHistory questionnaires,
    required List<Recording> recordings,
  }) => {
    FollowUpItem.adherence: outcome.isComplete,
    FollowUpItem.compliance: outcome.isComplete,
    FollowUpItem.usability: questionnaires.usability.isNotEmpty,
    FollowUpItem.feedback: questionnaires.satisfaction.isNotEmpty,
    FollowUpItem.postRecording: recordings.any(
      (r) =>
          r.kind == RecordingKind.probe &&
          !dateOnly(r.createdAt).isBefore(outcome.period.end),
    ),
  };
}
