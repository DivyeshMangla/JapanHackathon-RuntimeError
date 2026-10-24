import '../../auth/domain/user.dart';
import '../../exercises/domain/patient_activity.dart';
import '../../recordings/domain/probe_schedule.dart';
import '../../recordings/domain/recording.dart';
import '../../study/domain/participant_status.dart';

/// One patient with their recent activity and status, as therapists and
/// admins see them.
class ParticipantSummary {
  const ParticipantSummary({
    required this.patient,
    required this.activity,
    required this.recordings,
    required this.lowAdherence,
    required this.status,
    required this.probeDue,
  });

  final User patient;
  final PatientActivity activity;
  final List<Recording> recordings;

  /// Recent adherence is under the study's threshold setting.
  final bool lowAdherence;
  final ParticipantStatus status;
  final ProbeDue probeDue;

  String get code => patient.participantCode ?? patient.id;
}
