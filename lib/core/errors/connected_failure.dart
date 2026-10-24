/// Why a connected-account action failed. The screens map each reason to a
/// localized message; only [ConnectedFailureReason.rejected] carries the
/// server's own explanation, because the server owns those rules.
enum ConnectedFailureReason {
  offline,
  timeout,
  badResponse,
  sessionEnded,
  rejected,
  invalidServerAddress,
  httpsRequired,
  adminUsesDashboard,
  pinFormat,
  pinMismatch,
  wrongPin,
  pinLocked,
  biometricsDisabled,
  noBiometric,
  microphoneDenied,
  noRecording,
  recordingUnavailable,
  photoUnavailable,
  photoTooLarge,
}

final class ConnectedFailure implements Exception {
  const ConnectedFailure(
    this.reason, {
    this.status = 0,
    this.serverMessage,
    this.retryAfter,
  });

  final ConnectedFailureReason reason;

  /// HTTP status, or 0 when no response arrived.
  final int status;

  /// The server's message for a rejected request.
  final String? serverMessage;

  /// How long a PIN lockout still lasts.
  final Duration? retryAfter;

  bool get endsSession => status == 401 || status == 403;

  @override
  String toString() => 'ConnectedFailure(${reason.name}, $status)';
}
