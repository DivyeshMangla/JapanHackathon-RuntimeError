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

  /// Signs this device in as the child [childName] of the parent whose code
  /// is [parentCode], creating the child the first time.
  Future<User> setUpChild({
    required String parentCode,
    required String childName,
  });

  Future<void> signOut();

  /// The user whose session survived the last app launch, if any.
  Future<User?> restoreSession();
}
