import '../../questionnaires/domain/questionnaire.dart';
import 'intervention_outcome.dart';
import 'participant_record.dart';
import 'statistics.dart';

/// Everything the outcome measures need about one participant.
class ParticipantOutcome {
  const ParticipantOutcome({
    required this.patientId,
    required this.code,
    required this.record,
    required this.outcome,
    required this.questionnaires,
  });

  final String patientId;
  final String code;
  final ParticipantRecord record;
  final InterventionOutcome outcome;
  final QuestionnaireHistory questionnaires;

  /// Ended the intervention, whether or not they stayed to the end.
  bool reachedEnd(DateTime today) =>
      record.isWithdrawn || outcome.period.hasEnded(today);

  double? get susScore => questionnaires.usability.firstOrNull?.score;

  double? get satisfaction =>
      questionnaires.satisfaction.firstOrNull?.meanRating;

  /// Self-reported practice days at baseline and in the final study week,
  /// as percentages, when both reports exist.
  (double, double)? get selfReportPair {
    final before = questionnaires.baseline;
    final after = questionnaires.reportForWeek(outcome.period.weeks);
    if (before == null || after == null) return null;
    return (before.rate * 100, after.rate * 100);
  }
}

/// Self-reported practice before and after the intervention, with both
/// paired tests from the analysis plan.
class PrePostComparison {
  const PrePostComparison({
    required this.before,
    required this.after,
    required this.tTest,
    required this.wilcoxon,
  });

  final Descriptive? before;
  final Descriptive? after;
  final PairedTTestResult? tTest;
  final WilcoxonResult? wilcoxon;
}

/// The protocol's primary, feasibility and secondary outcome measures
/// across every enrolled participant.
class StudyOutcomes {
  const StudyOutcomes({
    required this.enrolled,
    required this.withdrawn,
    required this.completedIntervention,
    required this.recruitment,
    required this.retention,
    required this.usageCompletion,
    required this.adherence,
    required this.compliance,
    required this.atOrAboveThreshold,
    required this.usability,
    required this.satisfaction,
    required this.selfReport,
  });

  /// [approached] is how many eligible people were invited, entered by the
  /// research admin; recruitment rate is unknown without it.
  factory StudyOutcomes.compute({
    required List<ParticipantOutcome> participants,
    required int? approached,
    required double adherenceThreshold,
    required DateTime today,
  }) {
    final enrolled = participants.length;
    final withdrawn = participants.where((p) => p.record.isWithdrawn).length;
    final reachedEnd = participants.where((p) => p.reachedEnd(today));
    final adherenceRates = [for (final p in participants) ?p.outcome.adherence];
    final pairs = [for (final p in participants) ?p.selfReportPair];
    final before = [for (final (b, _) in pairs) b];
    final after = [for (final (_, a) in pairs) a];

    return StudyOutcomes(
      enrolled: enrolled,
      withdrawn: withdrawn,
      completedIntervention: participants
          .where((p) => !p.record.isWithdrawn && p.outcome.isComplete)
          .length,
      recruitment: approached == null || approached == 0
          ? null
          : Proportion(enrolled, approached),
      retention: Proportion(enrolled - withdrawn, enrolled),
      usageCompletion: Proportion(
        reachedEnd
            .where((p) => !p.record.isWithdrawn && p.outcome.usedEveryWeek)
            .length,
        reachedEnd.length,
      ),
      adherence: Descriptive.of([for (final r in adherenceRates) r * 100]),
      compliance: Descriptive.of([
        for (final p in participants)
          if (p.outcome.compliance case final rate?) rate * 100,
      ]),
      atOrAboveThreshold: Proportion(
        adherenceRates.where((r) => r >= adherenceThreshold).length,
        adherenceRates.length,
      ),
      usability: Descriptive.of([for (final p in participants) ?p.susScore]),
      satisfaction: Descriptive.of([
        for (final p in participants) ?p.satisfaction,
      ]),
      selfReport: PrePostComparison(
        before: Descriptive.of(before),
        after: Descriptive.of(after),
        tTest: PairedTests.tTest(before, after),
        wilcoxon: PairedTests.wilcoxon(before, after),
      ),
    );
  }

  final int enrolled;
  final int withdrawn;
  final int completedIntervention;

  /// Enrolled over approached; null until the admin enters approached.
  final Proportion? recruitment;

  /// Enrolled participants who have not withdrawn.
  final Proportion retention;

  /// Participants who used the app in every study week, over those whose
  /// intervention has ended (withdrawals count as not completing).
  final Proportion usageCompletion;

  /// Per-participant intervention adherence, in percent.
  final Descriptive? adherence;

  /// Per-participant compliance (full-dose days), in percent.
  final Descriptive? compliance;

  /// Participants at or above the study's adherence threshold.
  final Proportion atOrAboveThreshold;

  /// SUS scores, 0 to 100.
  final Descriptive? usability;

  /// Mean feedback rating per participant, 1 to 5.
  final Descriptive? satisfaction;
  final PrePostComparison selfReport;
}
