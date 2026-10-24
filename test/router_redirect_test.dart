import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:melo/core/routing/app_router.dart';
import 'package:melo/features/auth/domain/user.dart';

User _user(UserRole role) => User(
  id: 'u1',
  role: role,
  name: 'Test User',
  email: 'test@example.org',
  createdAt: DateTime(2026),
);

void main() {
  test('holds on splash while the session is restoring', () {
    expect(
      redirectFor(const AsyncLoading(), AppRoutes.patient),
      AppRoutes.splash,
    );
    expect(redirectFor(const AsyncLoading(), AppRoutes.splash), isNull);
  });

  test('sends signed-out users to login', () {
    expect(
      redirectFor(const AsyncData(null), AppRoutes.admin),
      AppRoutes.login,
    );
    expect(redirectFor(const AsyncData(null), AppRoutes.login), isNull);
    expect(redirectFor(const AsyncData(null), AppRoutes.sensorCheck), isNull);
  });

  test('keeps each role inside its own route tree', () {
    final patient = AsyncData<User?>(_user(UserRole.patient));
    expect(redirectFor(patient, AppRoutes.login), AppRoutes.patient);
    expect(redirectFor(patient, AppRoutes.therapist), AppRoutes.patient);
    expect(redirectFor(patient, '${AppRoutes.patient}/exercises'), isNull);

    final therapist = AsyncData<User?>(_user(UserRole.therapist));
    expect(redirectFor(therapist, AppRoutes.admin), AppRoutes.therapist);
    expect(redirectFor(therapist, '/patientx'), AppRoutes.therapist);
  });
}
