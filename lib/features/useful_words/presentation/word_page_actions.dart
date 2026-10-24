import 'package:flutter/material.dart';

import '../../../core/errors/connected_failure.dart';
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
    String? failure;
    try {
      await action();
    } on ConnectedFailure catch (e) {
      failure = e.serverMessage ?? WordStrings.error;
    } catch (_) {
      failure = WordStrings.error;
    }
    if (mounted) {
      setState(() {
        busy = false;
        error = failure;
      });
    }
    return failure == null;
  }
}
