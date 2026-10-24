import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/backend_client.dart';
import '../domain/auth_repository.dart';
import '../domain/user_repository.dart';
import 'backend_auth_repository.dart';
import 'backend_user_repository.dart';

final _backendUsersProvider = Provider<BackendUserRepository>(
  (ref) => BackendUserRepository(ref.watch(backendClientProvider)),
);

final userRepositoryProvider = Provider<UserRepository>(
  (ref) => ref.watch(_backendUsersProvider),
);

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => BackendAuthRepository(
    ref.watch(backendClientProvider),
    ref.watch(_backendUsersProvider),
  ),
);
