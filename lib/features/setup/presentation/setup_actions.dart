import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/setup_failure.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/setup_strings.dart';
import '../../../transport/file_transport.dart';
import '../../../transport/qr_transport.dart';
import '../../../transport/sync_envelope.dart';
import '../../../transport/sync_transport.dart';
import '../setup_app.dart';
import '../setup_service.dart';

/// Shared behaviour for every setup page: localized text, one action at a
/// time, and the action's failure as a message for the action panel.
mixin SetupActions<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  late final SetupService service = ref.read(setupServiceProvider);
  String? _working;
  String? error;

  bool get busy => _working != null;

  String s(String key) => SetupStrings.text(service.locale, key);

  String format(String key, Map<String, Object> values) =>
      SetupStrings.format(service.locale, key, values);

  /// The button's own label, or the waiting label while its action runs.
  String label(String key) => _working == key ? s('working') : s(key);

  @override
  void initState() {
    super.initState();
    service.addListener(_refresh);
  }

  @override
  void dispose() {
    service.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  /// A button callback for [body], or null while any action runs.
  VoidCallback? action(
    String key,
    Future<void> Function() body, {
    bool enabled = true,
  }) => busy || !enabled ? null : () => unawaited(run(key, body));

  Future<void> run(String key, Future<void> Function() body) async {
    if (busy) return;
    setState(() {
      _working = key;
      error = null;
    });
    try {
      await body();
    } on SetupFailure catch (failure) {
      _fail(s(setupFailureMessageKey(failure.reason)));
    } catch (failure, stack) {
      // Anything else is a corrupt or foreign package, or a storage error;
      // the user can only retry, so one message covers them all.
      AppLogger.error('Setup action $key failed', failure, stack);
      _fail(s('invalidPackage'));
    } finally {
      if (mounted) setState(() => _working = null);
    }
  }

  void _fail(String message) {
    if (mounted) setState(() => error = message);
  }

  Future<void> receive({
    required bool qr,
    required Future<void> Function(SyncEnvelope envelope) accept,
  }) async {
    final SyncTransport transport = qr ? QrTransport(context) : FileTransport();
    final envelope = await transport.receive();
    if (envelope != null) await accept(envelope);
  }

  /// Whether the user confirmed the package reached the other phone.
  Future<bool> send({
    required bool qr,
    required Future<SyncEnvelope> Function() envelope,
  }) async {
    final package = await envelope();
    if (!mounted) return false;
    final SyncTransport transport = qr ? QrTransport(context) : FileTransport();
    return transport.send(package);
  }
}

/// The ARB key of the message shown for [reason].
String setupFailureMessageKey(SetupFailureReason reason) => switch (reason) {
  SetupFailureReason.pinFormat => 'pinLength',
  SetupFailureReason.pinMismatch => 'pinMismatch',
  SetupFailureReason.wrongPin => 'wrongPin',
  SetupFailureReason.noBiometric => 'noBiometric',
  SetupFailureReason.codeUnavailable => 'codeUnavailable',
  SetupFailureReason.approvalRequired => 'approvalRequired',
  SetupFailureReason.busy => 'failureBusy',
  SetupFailureReason.wrongStep => 'failureWrongStep',
  SetupFailureReason.locked => 'failureLocked',
  SetupFailureReason.profileIncomplete => 'failureProfileIncomplete',
  SetupFailureReason.eraseConfirmation => 'failureEraseConfirmation',
  SetupFailureReason.notJoinPackage => 'failureNotJoinPackage',
  SetupFailureReason.unsupportedProfile => 'failureUnsupportedProfile',
  SetupFailureReason.unsupportedLanguage => 'failureUnsupportedLanguage',
  SetupFailureReason.narrationUnavailable => 'failureNarrationUnavailable',
  SetupFailureReason.offlineVoiceMissing => 'failureOfflineVoiceMissing',
  SetupFailureReason.consentIncomplete => 'failureConsentIncomplete',
  SetupFailureReason.signatureMissing => 'failureSignatureMissing',
  SetupFailureReason.consentNotReady => 'failureConsentNotReady',
  SetupFailureReason.notConsentPackage => 'failureNotConsentPackage',
  SetupFailureReason.wrongRecipient => 'failureWrongRecipient',
  SetupFailureReason.consentInvalid => 'failureConsentInvalid',
  SetupFailureReason.consentConflict => 'failureConsentConflict',
  SetupFailureReason.paperCopyRequired => 'failurePaperCopyRequired',
  SetupFailureReason.noPendingConsent => 'failureNoPendingConsent',
  SetupFailureReason.formsIncomplete => 'failureFormsIncomplete',
  SetupFailureReason.planPrerequisites => 'failurePlanPrerequisites',
  SetupFailureReason.planChoice => 'failurePlanChoice',
  SetupFailureReason.planMissing => 'failurePlanMissing',
  SetupFailureReason.planWrongRecipient => 'failurePlanWrongRecipient',
  SetupFailureReason.planInvalid => 'failurePlanInvalid',
  SetupFailureReason.baselineTask => 'failureBaselineTask',
  SetupFailureReason.baselineIncomplete => 'failureBaselineIncomplete',
};

/// The ARB key labelling [item]; "therapist" alone would read as the role.
String consentLabelKey(ConsentItem item) =>
    item == ConsentItem.therapist ? 'therapistConsent' : item.name;
