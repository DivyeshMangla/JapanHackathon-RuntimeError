import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/admin/presentation/admin_routes.dart';
import '../../features/auth/domain/user.dart';
import '../../features/auth/presentation/child_setup_screen.dart';
import '../../features/auth/presentation/controllers/auth_controller.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/parent_sign_up_screen.dart';
import '../../features/auth/presentation/splash_screen.dart';
import '../../features/auth/presentation/welcome_screen.dart';
import '../../features/diagnostics/presentation/sensor_check_screen.dart';
import '../../features/parent/presentation/parent_routes.dart';
import '../../features/patient/presentation/patient_routes.dart';
import '../../features/therapist/presentation/therapist_routes.dart';
import 'app_routes.dart';

export 'app_routes.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final auth = ValueNotifier<AsyncValue<User?>>(
    ref.read(authControllerProvider),
  );
  ref.listen(authControllerProvider, (_, next) => auth.value = next);

  final router = GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: auth,
    redirect: (context, state) =>
        redirectFor(auth.value, state.matchedLocation),
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.welcome,
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.parentSignUp,
        builder: (context, state) => const ParentSignUpScreen(),
      ),
      GoRoute(
        path: AppRoutes.childSetup,
        builder: (context, state) => const ChildSetupScreen(),
      ),
      GoRoute(
        path: AppRoutes.sensorCheck,
        builder: (context, state) => const SensorCheckScreen(),
      ),
      patientRoutes,
      parentRoutes,
      therapistRoutes,
      adminRoutes,
    ],
  );

  ref.onDispose(() {
    router.dispose();
    auth.dispose();
  });
  return router;
});

/// Role-based guard: signed-out users go to the welcome page, and signed-in
/// users are confined to the route tree that belongs to their role.
@visibleForTesting
String? redirectFor(AsyncValue<User?> auth, String location) {
  if (!auth.hasValue && !auth.hasError) {
    return location == AppRoutes.splash ? null : AppRoutes.splash;
  }

  final user = auth.value;
  if (user == null) {
    return AppRoutes.public.contains(location) ? null : AppRoutes.welcome;
  }

  final home = AppRoutes.homeFor(user.role);
  final inOwnTree = location == home || location.startsWith('$home/');
  return inOwnTree ? null : home;
}
