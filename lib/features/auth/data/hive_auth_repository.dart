import 'package:hive_ce/hive_ce.dart';

import '../../../core/errors/guard.dart';
import '../../../core/security/password_hasher.dart';
import '../domain/auth_repository.dart';
import '../domain/user.dart';
import '../domain/user_repository.dart';

class HiveAuthRepository implements AuthRepository {
  HiveAuthRepository({
    required Box<String> credentials,
    required Box<Object> meta,
    required UserRepository users,
    required PasswordHasher hasher,
  }) : _credentials = credentials,
       _meta = meta,
       _users = users,
       _hasher = hasher;

  static const _sessionKey = 'session.userId';

  final Box<String> _credentials;
  final Box<Object> _meta;
  final UserRepository _users;
  final PasswordHasher _hasher;

  @override
  Future<User?> signIn({required String email, required String password}) =>
      guardStorage(() async {
        final user = await _users.findByEmail(email);
        final hash = user == null ? null : _credentials.get(user.id);
        if (user == null || hash == null) return null;
        if (!await _hasher.verify(password, hash)) return null;

        await _meta.put(_sessionKey, user.id);
        return user;
      });

  @override
  Future<void> signOut() => guardStorage(() => _meta.delete(_sessionKey));

  @override
  Future<User?> restoreSession() => guardStorage(() async {
    final userId = _meta.get(_sessionKey) as String?;
    if (userId == null) return null;

    final user = await _users.findById(userId);
    if (user == null) await signOut();
    return user;
  });

  @override
  Future<void> setPassword({
    required String userId,
    required String password,
  }) => guardStorage(() async {
    await _credentials.put(userId, await _hasher.hash(password));
  });
}
