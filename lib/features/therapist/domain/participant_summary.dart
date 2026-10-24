import '../../auth/domain/user.dart';
import '../../recordings/domain/probe_schedule.dart';
import '../../recordings/domain/recording.dart';

/// One patient with their voice samples and probe schedule, as therapists
/// and admins see them.
class ParticipantSummary {
  const ParticipantSummary({
    required this.patient,
    required this.recordings,
    required this.probeDue,
  });

  final User patient;
  final List<Recording> recordings;
  final ProbeDue probeDue;

  String get code => patient.participantCode ?? patient.id;
}
