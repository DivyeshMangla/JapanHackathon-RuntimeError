import '../../../core/utils/dates.dart';
import '../../exercises/domain/voice_use_entry.dart';
import '../../questionnaires/domain/questionnaire.dart';
import '../../recordings/domain/recording.dart';
import '../../study/domain/assessment_checklist.dart';
import '../../study/domain/intervention_outcome.dart';
import '../../study/domain/monitoring_entry.dart';
import '../../study/domain/participant_record.dart';
import 'participant_summary.dart';

/// A caseload participant's study data for the assessment screens: the
/// application log, self-reports and therapist monitoring side by side.
class ParticipantStudy {
  const ParticipantStudy({
    required this.summary,
    required this.record,
    required this.outcome,
    required this.questionnaires,
    required this.monitoring,
    this.voiceDiary = const [],
  });

  final ParticipantSummary summary;
  final ParticipantRecord record;
  final InterventionOutcome outcome;
  final QuestionnaireHistory questionnaires;
  final List<MonitoringEntry> monitoring;

  /// Voice-use monitoring entries, oldest first.
  final List<VoiceUseEntry> voiceDiary;

  Map<BaselineItem, bool> get baseline => AssessmentChecklist.baseline(
    record: record,
    questionnaires: questionnaires,
    recordings: summary.recordings,
  );

  Map<FollowUpItem, bool> get followUp => AssessmentChecklist.followUp(
    outcome: outcome,
    questionnaires: questionnaires,
    recordings: summary.recordings,
  );

  /// Home practice recordings saved during study [week].
  int practiceRecordingsInWeek(int week) {
    final period = outcome.period;
    return summary.recordings
        .where(
          (r) =>
              r.type == RecordingType.homePractice &&
              period.weekOf(dateOnly(r.createdAt)) == week,
        )
        .length;
  }

  List<MonitoringEntry> monitoringForWeek(int week) =>
      monitoring.where((m) => m.week == week).toList();
}
