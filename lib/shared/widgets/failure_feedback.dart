import 'package:flutter/material.dart';

import '../../core/errors/app_failure.dart';
import '../../core/utils/l10n.dart';

/// Runs [action]; if it fails with an [AppFailure], tells the user why in a
/// snackbar. Returns whether the action succeeded.
Future<bool> runWithFailureMessage(
  BuildContext context,
  Future<void> Function() action,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final l10n = context.l10n;
  try {
    await action();
    return true;
  } on AppFailure catch (failure) {
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.failureMessage(failure))),
    );
    return false;
  }
}
