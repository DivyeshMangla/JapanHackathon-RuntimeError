import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../usage/domain/usage_event.dart';
import '../../../usage/presentation/controllers/usage_controllers.dart';
import '../../data/auth_repository_providers.dart';
import '../../domain/auth_repository.dart';
import '../../domain/user.dart';

final userByIdProvider = FutureProvider.family<User?, String>(
  (ref, id) => ref.watch(userRepositoryProvider).findById(id),
);

/// The signed-in user, or null when signed out.
final authControllerProvider = AsyncNotifierProvider<AuthController, User?>(
  AuthController.new,
);

/// The signed-in user for screens behind [SignedInGate]. Throws when nobody
/// is signed in, which the gate prevents.
final currentUserProvider = Provider<User>((ref) {
  final user = ref.watch(authControllerProvider).value;
  if (user == null) throw StateError('No user is signed in');
  return user;
});

class AuthController extends AsyncNotifier<User?> {
  AuthRepository get _repository => ref.read(authRepositoryProvider);

  @override
  Future<User?> build() => _repository.restoreSession();

  /// Returns false on bad credentials without disturbing the current state,
  /// so the router does not react to a failed attempt.
  Future<bool> signIn({required String email, required String password}) async {
    final user = await _repository.signIn(email: email, password: password);
    if (user == null) return false;
    state = AsyncData(user);
    await ref.read(usageLoggerProvider).record(UsageAction.signIn, user: user);
    return true;
  }

  Future<void> signOut() async {
    await ref
        .read(usageLoggerProvider)
        .record(UsageAction.signOut, user: state.value);
    await _repository.signOut();
    state = const AsyncData(null);
  }
}
