import '../../../core/errors/app_failure.dart';
import '../../../core/network/backend_client.dart';
import '../domain/auth_repository.dart';
import '../domain/user.dart';
import 'backend_user_repository.dart';

/// Sign-in against the care service. The bearer token lives in secure
/// storage, so a restart restores the session without asking again.
class BackendAuthRepository implements AuthRepository {
  BackendAuthRepository(this._client, this._users);

  final BackendClient _client;
  final BackendUserRepository _users;

  @override
  Future<User?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.post(
        '/auth/login',
        body: {'email': email.trim(), 'password': password, 'client': 'mobile'},
      );
      await _client.setToken(response['token'] as String?);
      final user = userFromApi(response.object('user'));
      _users.remember(user, current: true);
      return user;
    } on NetworkFailure catch (failure) {
      // A wrong password is an ordinary outcome, not an error to report.
      if (failure.status == 401) return null;
      rethrow;
    }
  }

  @override
  Future<User> registerParent({
    required String name,
    required String email,
    required String password,
    required String therapistCode,
  }) async {
    try {
      await _client.post(
        '/auth/register',
        body: {
          'role': UserRole.parent.name,
          'name': name.trim(),
          'email': email.trim(),
          'password': password,
          'therapistCode': therapistCode.trim(),
        },
      );
    } on NetworkFailure catch (failure) {
      if (failure.status == 409) {
        throw const InvalidInputFailure(InputProblem.emailTaken);
      }
      rethrow;
    }
    final user = await signIn(email: email, password: password);
    if (user == null) throw const NetworkFailure(NetworkProblem.badResponse);
    return user;
  }

  @override
  Future<User> startChildMode(String childId, String pin) async => _adopt(
    await _client.post('/patients/$childId/child-mode', body: {'pin': pin}),
  );

  @override
  Future<User?> endChildMode(String pin) async {
    try {
      return await _adopt(
        await _client.post('/auth/end-child-mode', body: {'pin': pin}),
      );
    } on NetworkFailure catch (failure) {
      // A wrong PIN keeps the child where they are.
      if (failure.status == 403) return null;
      rethrow;
    }
  }

  /// Switches this device to the session in [response]. People the previous
  /// account could see are forgotten, so the child never sees the parent's
  /// list or the other way round.
  Future<User> _adopt(JsonObject response) async {
    await _client.setToken(response['token'] as String?);
    final user = userFromApi(response.object('user'));
    _users
      ..forget()
      ..remember(user, current: true);
    return user;
  }

  @override
  Future<User?> restoreSession() async {
    if (!await _client.hasSession) return null;
    try {
      final response = await _client.get('/auth/me');
      final user = userFromApi(response.object('user'));
      _users.remember(user, current: true);
      return user;
    } on NetworkFailure catch (failure) {
      if (failure.problem == NetworkProblem.sessionEnded) {
        await _client.setToken(null);
        return null;
      }
      rethrow;
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _client.post('/auth/logout');
    } on NetworkFailure {
      // The token is dropped locally either way; an unreachable server must
      // not keep someone signed in on a shared phone.
    }
    await _client.setToken(null);
    _users.forget();
  }
}
