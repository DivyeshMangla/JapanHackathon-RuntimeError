import '../../features/auth/domain/user.dart';

abstract final class AppRoutes {
  static const splash = '/';
  static const welcome = '/welcome';
  static const login = '/login';
  static const parentSignUp = '/sign-up';

  /// Developer sensor check, reachable while signed out.
  static const sensorCheck = '/sensor-check';

  /// Pages a signed-out visitor may open.
  static const public = {welcome, login, parentSignUp, sensorCheck};

  /// The child's area, opened by a parent's child mode. The path keeps the
  /// service's name for the role.
  static const patient = '/patient';
  static const patientWords = '/patient/words';
  static const patientDrawing = '/patient/drawing';
  static const patientExpressions = '/patient/expressions';
  static const patientProgress = '/patient/progress';
  static String patientDrawingExercise(String exerciseId) =>
      '$patientDrawing/$exerciseId';

  static const parent = '/parent';
  static String parentChild(String id) => '$parent/children/$id';
  static const parentAddChild = '/parent/add-child';
  static const parentSettings = '/parent/settings';

  static const therapist = '/therapist';
  static const therapistParticipants = '/therapist/participants';
  static String therapistParticipant(String id) => '$therapistParticipants/$id';
  static String therapistWords(String id) =>
      '${therapistParticipant(id)}/words';
  static String therapistDrawing(String id) =>
      '${therapistParticipant(id)}/drawing';
  static String therapistExpressions(String id) =>
      '${therapistParticipant(id)}/expressions';
  static const therapistRecordings = '/therapist/recordings';
  static String therapistRecordingsFor(String patientId) =>
      '$therapistRecordings?patient=$patientId';
  static String therapistUsage(String id) =>
      '${therapistParticipant(id)}/usage';
  static const admin = '/admin';
  static const adminPeople = '/admin/people';
  static String adminNewUser(UserRole role) =>
      '$adminPeople/new?role=${role.name}';
  static const adminSettings = '/admin/settings';
  static const adminAccessLog = '$adminSettings/access-log';

  static String homeFor(UserRole role) => switch (role) {
    UserRole.patient => patient,
    UserRole.parent => parent,
    UserRole.therapist => therapist,
    UserRole.admin => admin,
  };
}
