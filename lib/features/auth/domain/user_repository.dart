import 'user.dart';

abstract interface class UserRepository {
  Future<User?> findById(String id);

  /// Everyone with [role] that the signed-in user may see, patients ordered
  /// by participant code and staff by name.
  Future<List<User>> listByRole(UserRole role);

  /// Patients assigned to [therapistId], ordered by participant code.
  Future<List<User>> patientsOf(String therapistId);

  /// Creates an account. Throws an [InvalidInputFailure] when the email is
  /// already in use.
  Future<User> create({
    required UserRole role,
    required String name,
    required String email,
    required String password,
    String? therapistId,
  });

  Future<void> assignTherapist({
    required String patientId,
    required String therapistId,
  });
}
