import 'user.dart';

abstract interface class AuthRepository {
  /// Returns the signed-in user, or null when the credentials do not match.
  Future<User?> signIn({required String email, required String password});

  /// Creates a parent account on the caseload of the therapist whose code
  /// is [therapistCode], then signs it in.
  Future<User> registerParent({
    required String name,
    required String email,
    required String password,
    required String therapistCode,
  });

  /// Hands the device to the signed-in parent's child [childId]. The
  /// parent's own session ends, so only their password brings it back.
  Future<User> startChildMode(String childId);

  /// Returns the parent to their own account, or null when [password] is
  /// not the parent's.
  Future<User?> endChildMode(String password);

  Future<void> signOut();

  /// The user whose session survived the last app launch, if any.
  Future<User?> restoreSession();
}
