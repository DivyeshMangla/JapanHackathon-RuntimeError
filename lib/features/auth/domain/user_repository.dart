import 'user.dart';

abstract interface class UserRepository {
  Future<User?> findById(String id);

  /// Lookup is case-insensitive.
  Future<User?> findByEmail(String email);

  Future<int> count();

  /// Everyone with [role], patients ordered by participant code and staff
  /// by name.
  Future<List<User>> listByRole(UserRole role);

  /// Patients assigned to [therapistId], ordered by participant code.
  Future<List<User>> patientsOf(String therapistId);

  Future<void> save(User user);
}
