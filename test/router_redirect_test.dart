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

  test('sends signed-out users to the welcome page', () {
    expect(
      redirectFor(const AsyncData(null), AppRoutes.admin),
      AppRoutes.welcome,
    );
    expect(
      redirectFor(const AsyncData(null), AppRoutes.parent),
      AppRoutes.welcome,
    );
    for (final open in [
      AppRoutes.welcome,
      AppRoutes.login,
      AppRoutes.parentSignUp,
      AppRoutes.sensorCheck,
    ]) {
      expect(redirectFor(const AsyncData(null), open), isNull);
    }
  });

  test('keeps each role inside its own route tree', () {
    final patient = AsyncData<User?>(_user(UserRole.patient));
    expect(redirectFor(patient, AppRoutes.login), AppRoutes.patient);
    expect(redirectFor(patient, AppRoutes.therapist), AppRoutes.patient);
    expect(redirectFor(patient, AppRoutes.patientDrawing), isNull);
    expect(redirectFor(patient, AppRoutes.parent), AppRoutes.patient);

    final parent = AsyncData<User?>(_user(UserRole.parent));
    expect(redirectFor(parent, AppRoutes.parentAddChild), isNull);
    expect(redirectFor(parent, AppRoutes.patient), AppRoutes.parent);
    expect(redirectFor(parent, AppRoutes.parentSettings), isNull);

    final therapist = AsyncData<User?>(_user(UserRole.therapist));
    expect(redirectFor(therapist, AppRoutes.admin), AppRoutes.therapist);
    expect(redirectFor(therapist, '/patientx'), AppRoutes.therapist);
  });
}
