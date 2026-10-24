import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/startup_failure_view.dart';

/// Shown instead of the app when it cannot start. The device's language is
/// not known yet at that point, so callers pass English text.
class StartupMessage extends StatelessWidget {
  const StartupMessage(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: StartupFailureView(message: message),
    );
  }
}
