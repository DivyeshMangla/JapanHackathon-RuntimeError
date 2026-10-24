import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/l10n.dart';
import 'melo_logo.dart';

/// Continues the native splash: the same logo, size and position on the same
/// flat page colour, so the hand-over from the platform is invisible.
class LaunchView extends StatelessWidget {
  const LaunchView({super.key});

  @override
  Widget build(BuildContext context) => const ColoredBox(
    color: AppColors.paper,
    child: Center(child: MeloLogo()),
  );
}

/// Runs from the first frame while storage opens, which can take seconds on
/// first launch; `main` then replaces it with the real app.
class LaunchApp extends StatelessWidget {
  const LaunchApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: const LaunchView(),
  );
}
