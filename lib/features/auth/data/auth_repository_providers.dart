import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/security/password_hasher.dart';
import '../../../core/storage/local_database.dart';
import '../domain/auth_repository.dart';
import '../domain/user_repository.dart';
import 'hive_auth_repository.dart';
import 'hive_user_repository.dart';

final passwordHasherProvider = Provider<PasswordHasher>(
  (ref) => const PasswordHasher(),
);

final userRepositoryProvider = Provider<UserRepository>(
  (ref) => HiveUserRepository(ref.watch(localDatabaseProvider).users),
);

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final db = ref.watch(localDatabaseProvider);
  return HiveAuthRepository(
    credentials: db.credentials,
    meta: db.meta,
    users: ref.watch(userRepositoryProvider),
    hasher: ref.watch(passwordHasherProvider),
  );
});
