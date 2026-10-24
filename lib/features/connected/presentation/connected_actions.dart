import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/errors/connected_failure.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/utils/l10n.dart';
import '../data/connected_service.dart';

extension ConnectedFailureText on AppLocalizations {
  String connectedFailureMessage(ConnectedFailure failure) =>
      switch (failure.reason) {
        ConnectedFailureReason.offline => connectedFailureOffline,
        ConnectedFailureReason.timeout => connectedFailureTimeout,
        ConnectedFailureReason.badResponse => connectedFailureBadResponse,
        ConnectedFailureReason.sessionEnded => connectedFailureSessionEnded,
        ConnectedFailureReason.rejected =>
          failure.serverMessage ?? connectedFailureRejected,
        ConnectedFailureReason.invalidServerAddress =>
          connectedFailureInvalidServer,
        ConnectedFailureReason.httpsRequired => connectedFailureHttps,
        ConnectedFailureReason.adminUsesDashboard => connectedFailureAdmin,
        ConnectedFailureReason.pinFormat => connectedPinLength,
        ConnectedFailureReason.pinMismatch => connectedPinMismatch,
        ConnectedFailureReason.wrongPin => connectedFailureWrongPin,
        ConnectedFailureReason.pinLocked => connectedFailurePinLocked(
          (failure.retryAfter ?? Duration.zero).inSeconds,
        ),
        ConnectedFailureReason.biometricsDisabled =>
          connectedFailureBiometricsDisabled,
        ConnectedFailureReason.noBiometric => connectedFailureNoBiometric,
        ConnectedFailureReason.microphoneDenied => connectedFailureMicrophone,
        ConnectedFailureReason.noRecording => connectedFailureNoRecording,
        ConnectedFailureReason.recordingUnavailable =>
          connectedFailureRecordingUnavailable,
      };
}

/// Shared behaviour for connected pages: one action at a time, a waiting
/// label on the button that started it, and its failure as a message for
/// the action panel.
mixin ConnectedActions<T extends StatefulWidget> on State<T> {
  ConnectedService get service;

  String? _working;
  String? error;

  bool get busy => _working != null;

  /// [text], or the waiting label while the action named [key] runs.
  String label(String key, String text) =>
      _working == key ? context.l10n.connectedWorking : text;

  /// A button callback for [body], or null while any action runs.
  VoidCallback? action(
    String key,
    Future<void> Function() body, {
    bool enabled = true,
  }) => busy || !enabled ? null : () => unawaited(run(key, body));

  /// Runs [body] and returns whether it succeeded.
  Future<bool> run(String key, Future<void> Function() body) async {
    if (busy) return false;
    final l10n = context.l10n;
    setState(() {
      _working = key;
      error = null;
    });
    String? message;
    try {
      await body();
    } on ConnectedFailure catch (failure) {
      message = l10n.connectedFailureMessage(failure);
    } on AppFailure catch (failure) {
      message = l10n.failureMessage(failure);
    } catch (failure, stack) {
      AppLogger.error('Connected action $key failed', failure, stack);
      message = l10n.connectedFailureBadResponse;
    }
    if (mounted) {
      setState(() {
        _working = null;
        error = message;
      });
    }
    return message == null;
  }
}
