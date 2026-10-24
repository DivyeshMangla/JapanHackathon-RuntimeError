import 'package:flutter/material.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/utils/l10n.dart';
import 'word_strings.dart';

mixin WordPageActions<T extends StatefulWidget> on State<T> {
  bool busy = false;
  String? error;
  Future<bool> run(Future<void> Function() action) async {
    if (busy) return false;
    setState(() {
      busy = true;
      error = null;
    });
    Object? failure;
    try {
      await action();
    } on AppFailure catch (e) {
      failure = e;
    } catch (e, stack) {
      AppLogger.error('Word practice action failed', e, stack);
      failure = e;
    }
    // The message is looked up only now: a page may start loading from
    // initState, before it can read inherited widgets.
    if (mounted) {
      setState(() {
        busy = false;
        error = switch (failure) {
          null => null,
          final AppFailure known => context.l10n.failureMessage(known),
          _ => WordStrings.error,
        };
      });
    }
    return failure == null;
  }
}
