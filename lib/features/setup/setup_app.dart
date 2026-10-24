import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/setup_state.dart';
import '../../core/setup_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import 'presentation/setup_screen.dart';
import 'setup_service.dart';

final setupServiceProvider = Provider<SetupService>(
  (ref) => throw StateError('Setup is not initialized'),
);

String? setupRedirect(SetupService service, String location) {
  final expected = service.state.route(unlocked: service.unlocked);
  if (service.state.stage == SetupStage.ready &&
      service.unlocked &&
      (location == '/ready' || location.startsWith('/therapist/'))) {
    return null;
  }
  return location == expected ? null : expected;
}

class SetupApp extends ConsumerStatefulWidget {
  const SetupApp({super.key});
  @override
  ConsumerState<SetupApp> createState() => _SetupAppState();
}

class _SetupAppState extends ConsumerState<SetupApp>
    with WidgetsBindingObserver {
  late final SetupService service;
  late final GoRouter router;
  DateTime? backgrounded;
  bool obscured = false;
  @override
  void initState() {
    super.initState();
    service = ref.read(setupServiceProvider);
    service.addListener(refresh);
    WidgetsBinding.instance.addObserver(this);
    router = GoRouter(
      initialLocation: service.state.route(unlocked: false),
      refreshListenable: service,
      redirect: (_, state) => setupRedirect(service, state.uri.path),
      routes: [
        for (final stage in SetupStage.values)
          GoRoute(
            path: '/${stage.name}',
            builder: (_, _) => SetupScreen(page: stage.name),
          ),
        GoRoute(
          path: '/unlock',
          builder: (_, _) => const SetupScreen(page: 'unlock'),
        ),
        GoRoute(
          path: '/therapist/join',
          builder: (_, _) => const SetupScreen(page: 'joinCode'),
        ),
        for (final page in ['patient', 'forms', 'prescribe', 'transfer'])
          GoRoute(
            path: '/therapist/$page/:id',
            builder: (_, state) => SetupScreen(
              key: ValueKey(state.uri.path),
              page: page,
              participantId: state.pathParameters['id'],
            ),
          ),
      ],
    );
  }

  void refresh() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      backgrounded ??= DateTime.now();
      if (mounted) setState(() => obscured = true);
    } else if (state == AppLifecycleState.resumed) {
      if (backgrounded != null &&
          DateTime.now().difference(backgrounded!).inSeconds >= 60) {
        service.lock();
      }
      backgrounded = null;
      if (mounted) setState(() => obscured = false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    service.removeListener(refresh);
    router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp.router(
    onGenerateTitle: (_) => SetupStrings.text(service.locale, 'appTitle'),
    debugShowCheckedModeBanner: false,
    locale: Locale(service.locale),
    supportedLocales: const [Locale('en'), Locale('hi'), Locale('pa')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    theme: AppTheme.light,
    themeMode: ThemeMode.light,
    routerConfig: router,
    builder: (_, child) => DecoratedBox(
      decoration: const BoxDecoration(gradient: AppColors.pageGradient),
      child: Stack(
        children: [
          child!,
          // Hides patient details from the app switcher's snapshot.
          if (obscured)
            const Positioned.fill(child: ColoredBox(color: AppColors.paper)),
        ],
      ),
    ),
  );
}
