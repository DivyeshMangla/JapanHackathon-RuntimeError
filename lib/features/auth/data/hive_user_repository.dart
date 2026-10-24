import 'package:hive_ce/hive_ce.dart';

import '../../../core/errors/guard.dart';
import '../domain/user.dart';
import '../domain/user_repository.dart';

class HiveUserRepository implements UserRepository {
  HiveUserRepository(this._box);

  final Box<Map<dynamic, dynamic>> _box;

  @override
  Future<User?> findById(String id) => guardStorage(() async {
    final map = _box.get(id);
    return map == null ? null : User.fromMap(map);
  });

  @override
  Future<User?> findByEmail(String email) => guardStorage(() async {
    final needle = email.trim().toLowerCase();
    for (final map in _box.values) {
      if ((map['email'] as String).toLowerCase() == needle) {
        return User.fromMap(map);
      }
    }
    return null;
  });

  @override
  Future<int> count() => guardStorage(() => _box.length);

  @override
  Future<List<User>> listByRole(UserRole role) => guardStorage(() async {
    final users = _box.values
        .where((m) => m['role'] == role.name)
        .map(User.fromMap)
        .toList();
    return users..sort(
      (a, b) => role == UserRole.patient
          ? (a.participantCode ?? '').compareTo(b.participantCode ?? '')
          : a.name.compareTo(b.name),
    );
  });

  @override
  Future<List<User>> patientsOf(String therapistId) => guardStorage(
    () =>
        _box.values
            .where((m) => m['therapistId'] == therapistId)
            .map(User.fromMap)
            .toList()
          ..sort(
            (a, b) =>
                (a.participantCode ?? '').compareTo(b.participantCode ?? ''),
          ),
  );

  @override
  Future<void> save(User user) =>
      guardStorage(() => _box.put(user.id, user.toMap()));
}
