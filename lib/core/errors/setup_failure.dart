/// Why a setup action was refused. The setup screens map each reason to a
/// localized message, so the service and crypto layers carry no display text.
enum SetupFailureReason {
  busy,
  wrongStep,
  locked,
  profileIncomplete,
  pinFormat,
  pinMismatch,
  wrongPin,
  noBiometric,
  eraseConfirmation,
  notJoinPackage,
  unsupportedProfile,
  codeUnavailable,
  unsupportedLanguage,
  narrationUnavailable,
  offlineVoiceMissing,
  consentIncomplete,
  signatureMissing,
  consentNotReady,
  notConsentPackage,
  wrongRecipient,
  consentInvalid,
  consentConflict,
  paperCopyRequired,
  noPendingConsent,
  approvalRequired,
  formsIncomplete,
  planPrerequisites,
  planChoice,
  planMissing,
  planWrongRecipient,
  planInvalid,
  baselineTask,
  baselineIncomplete,
}

/// A setup action the user can correct, as opposed to a corrupt package or
/// storage error, which the screens report generically.
final class SetupFailure implements Exception {
  const SetupFailure(this.reason);

  final SetupFailureReason reason;

  @override
  String toString() => 'SetupFailure(${reason.name})';
}
