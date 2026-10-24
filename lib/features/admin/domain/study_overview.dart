import '../../study/domain/participant_status.dart';

class StudyOverview {
  const StudyOverview({
    required this.enrolled,
    required this.therapists,
    required this.overallAdherence,
    required this.lowAdherence,
    required this.statusCounts,
  });

  final int enrolled;
  final int therapists;

  /// Prescribed sessions completed across all patients, last 14 days.
  final double? overallAdherence;
  final int lowAdherence;
  final Map<ParticipantStatus, int> statusCounts;
}
