import '../../features/auth/domain/user.dart';
import '../../features/education/domain/education_topic.dart';

abstract final class AppRoutes {
  static const splash = '/';
  static const login = '/login';

  /// Developer sensor check, reachable while signed out.
  static const sensorCheck = '/sensor-check';

  static const patient = '/patient';
  static const patientExercises = '/patient/exercises';
  static String patientExercise(String id) => '$patientExercises/$id';
  static String patientVoiceDiary(String exerciseId) =>
      '${patientExercise(exerciseId)}/diary';
  static const patientRecord = '/patient/record';
  static const patientProgress = '/patient/progress';
  static const patientProfile = '/patient/profile';
  static const patientProfileProgress = '$patientProfile?section=progress';
  static const patientProfileReminders = '$patientProfile?section=reminders';
  static const patientRecordings = '$patientProfile/recordings';
  static const patientLearn = '/patient/learn';
  static String patientLearnTopic(EducationTopic topic) =>
      '$patientLearn/${topic.name}';
  static String patientSelfReport(int week) =>
      '/patient/questionnaires/self-report/$week';
  static const patientUsability = '/patient/questionnaires/usability';
  static const patientFeedback = '/patient/questionnaires/feedback';

  static const therapist = '/therapist';
  static const therapistParticipants = '/therapist/participants';
  static String therapistParticipant(String id) => '$therapistParticipants/$id';
  static String therapistAdherence(String id) =>
      '${therapistParticipant(id)}/adherence';
  static String therapistAssign(String id, {String? scheduleId}) =>
      '${therapistParticipant(id)}/assign'
      '${scheduleId == null ? '' : '?schedule=$scheduleId'}';
  static const therapistRecordings = '/therapist/recordings';
  static String therapistRecordingsFor(String patientId) =>
      '$therapistRecordings?patient=$patientId';
  static String therapistStudyRecord(String id) =>
      '${therapistParticipant(id)}/record';
  static String therapistAssessment(String id) =>
      '${therapistParticipant(id)}/assessment';
  static String therapistMonitoringForm(String id, int week) =>
      '${therapistAssessment(id)}/monitoring?week=$week';
  static String therapistUsage(String id) =>
      '${therapistParticipant(id)}/usage';
  static const admin = '/admin';
  static const adminOutcomes = '/admin/outcomes';
  static const adminPeople = '/admin/people';
  static String adminNewUser(UserRole role) =>
      '$adminPeople/new?role=${role.name}';
  static const adminLibrary = '/admin/library';
  static const adminNewExercise = '$adminLibrary/new';
  static String adminExercise(String id) => '$adminLibrary/$id';
  static const adminSettings = '/admin/settings';
  static const adminAccessLog = '$adminSettings/access-log';

  static String homeFor(UserRole role) => switch (role) {
    UserRole.patient => patient,
    UserRole.therapist => therapist,
    UserRole.admin => admin,
  };
}
