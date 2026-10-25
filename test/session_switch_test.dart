import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:melo/features/auth/data/auth_repository_providers.dart';
import 'package:melo/features/auth/domain/user.dart';
import 'package:melo/features/auth/domain/user_repository.dart';
import 'package:melo/features/auth/presentation/controllers/auth_controller.dart';
import 'package:melo/features/auth/presentation/signed_in_gate.dart';
import 'package:melo/features/parent/presentation/controllers/family_controllers.dart';
import 'package:melo/features/therapist/presentation/controllers/caseload_controllers.dart';

User _account(String id, UserRole role) => User(
  id: id,
  role: role,
  name: 'Account $id',
  email: '$id@example.org',
  createdAt: DateTime(2026),
);

class _Session extends AuthController {
  _Session(this._first);

  final User _first;

  @override
  Future<User?> build() async => _first;

  void set(User? user) => state = AsyncData(user);
}

class _Users implements UserRepository {
  final requested = <String>[];

  @override
  Future<List<User>> patientsOf(String therapistId) async {
    requested.add(therapistId);
    return const [];
  }

  @override
  Future<List<User>> listByRole(UserRole role) async {
    requested.add(role.name);
    return const [];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Watcher extends ConsumerWidget {
  const _Watcher(this.provider);

  final ProviderListenable<AsyncValue<Object?>> provider;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Text(
    ref.watch(provider).hasValue ? 'loaded' : 'loading',
    textDirection: TextDirection.ltr,
  );
}

/// Signs in as [first], out, then in as [second] in one container, the way
/// signing out or leaving child mode does on a shared phone.
Future<void> _switchSessions(
  WidgetTester tester, {
  required ProviderListenable<AsyncValue<Object?>> provider,
  required User first,
  required User second,
  required _Users users,
}) async {
  final container = ProviderContainer(
    overrides: [
      authControllerProvider.overrideWith(() => _Session(first)),
      userRepositoryProvider.overrideWithValue(users),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(home: SignedInGate(child: _Watcher(provider))),
    ),
  );
  await tester.pumpAndSettle();
  expect(find.text('loaded'), findsOneWidget);
  final session = container.read(authControllerProvider.notifier) as _Session;
  session.set(null);
  await tester.pumpAndSettle();
  session.set(second);
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
  expect(find.text('loaded'), findsOneWidget);
}

void main() {
  testWidgets('a new therapist session rebuilds the caseload without errors', (
    tester,
  ) async {
    final users = _Users();
    await _switchSessions(
      tester,
      provider: caseloadProvider,
      first: _account('first', UserRole.therapist),
      second: _account('second', UserRole.therapist),
      users: users,
    );
    expect(users.requested, ['first', 'second']);
  });

  testWidgets('returning to a parent session rebuilds the family list', (
    tester,
  ) async {
    final users = _Users();
    await _switchSessions(
      tester,
      provider: familyChildrenProvider,
      first: _account('parent', UserRole.parent),
      second: _account('parent', UserRole.parent),
      users: users,
    );
    expect(users.requested, ['patient', 'patient']);
  });
}
