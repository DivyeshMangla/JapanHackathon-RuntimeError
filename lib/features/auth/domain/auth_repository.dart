import 'user.dart';

abstract interface class AuthRepository {
  /// Returns the signed-in user, or null when the credentials do not match.
  Future<User?> signIn({required String email, required String password});

  Future<void> signOut();

  /// The user whose session survived the last app launch, if any.
  Future<User?> restoreSession();

  Future<void> setPassword({required String userId, required String password});
}
