import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/l10n.dart';
import '../../../shared/widgets/startup_failure_view.dart';
import '../data/connected_service.dart';
import 'access_page.dart';
import 'lock_page.dart';
import 'patient_home_page.dart';
import 'therapist_home_page.dart';

/// A therapist who leaves the app for this long must enter their PIN again.
const _lockAfter = Duration(seconds: 60);

class ConnectedApp extends StatefulWidget {
  const ConnectedApp({super.key, required this.service});

  final ConnectedService service;

  @override
  State<ConnectedApp> createState() => _ConnectedAppState();
}

class _ConnectedAppState extends State<ConnectedApp>
    with WidgetsBindingObserver {
  final _navigator = GlobalKey<NavigatorState>();
  DateTime? _backgrounded;
  bool _obscured = false;
  bool _wasLocked = false;

  ConnectedService get _service => widget.service;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _service.addListener(_closePagesOnLock);
  }

  @override
  void dispose() {
    _service.removeListener(_closePagesOnLock);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// The lock page replaces the root page, so any patient page opened on top
  /// of it is closed too.
  void _closePagesOnLock() {
    if (_service.locked && !_wasLocked) {
      _navigator.currentState?.popUntil((route) => route.isFirst);
    }
    _wasLocked = _service.locked;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _backgrounded ??= DateTime.now();
      setState(() => _obscured = true);
    } else if (state == AppLifecycleState.resumed) {
      final away = _backgrounded == null
          ? Duration.zero
          : DateTime.now().difference(_backgrounded!);
      if (away >= _lockAfter) _service.lock();
      _backgrounded = null;
      setState(() => _obscured = false);
      if (!_service.locked) unawaited(_service.refresh());
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _service,
      builder: (context, _) {
        final user = _service.user;
        return MaterialApp(
          // A new account gets a fresh navigator, so no page of the previous
          // account stays on the back stack.
          key: ValueKey(user?.id),
          navigatorKey: _navigator,
          onGenerateTitle: (context) => context.l10n.appTitle,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          themeMode: ThemeMode.light,
          home: _RootPage(service: _service),
          builder: (context, child) => DecoratedBox(
            decoration: const BoxDecoration(gradient: AppColors.pageGradient),
            child: Stack(
              children: [
                child!,
                // Hides patient details from the app switcher's snapshot.
                if (_obscured)
                  const Positioned.fill(
                    child: ColoredBox(color: AppColors.paper),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Chooses the root page from the account state. It listens itself because
/// a route caches its page, so a changed `home` alone would not show.
class _RootPage extends StatelessWidget {
  const _RootPage({required this.service});

  final ConnectedService service;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: service,
      builder: (context, _) => service.user == null
          ? AccessPage(service: service)
          : service.locked
          ? LockPage(service: service)
          : service.isTherapist
          ? TherapistHomePage(service: service)
          : PatientHomePage(service: service),
    );
  }
}

/// Shown instead of the app when the connected store cannot be opened.
class ConnectedStartupFailure extends StatelessWidget {
  const ConnectedStartupFailure({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: Builder(
        builder: (context) =>
            StartupFailureView(message: context.l10n.connectedStartupFailed),
      ),
    );
  }
}
