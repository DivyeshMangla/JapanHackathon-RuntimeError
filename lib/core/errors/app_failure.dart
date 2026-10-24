/// Failures the app knows how to explain to the user. Repositories and
/// services convert low-level exceptions into one of these; the UI maps each
/// to a localized message (see `FailureText` in core/utils/l10n.dart).
sealed class AppFailure implements Exception {
  const AppFailure([this.cause]);

  /// The underlying error, for logs only. Never shown to the user.
  final Object? cause;

  @override
  String toString() => '$runtimeType($cause)';
}

/// Reading or writing local data failed.
final class StorageFailure extends AppFailure {
  const StorageFailure([super.cause]);
}

/// Capturing, encrypting or saving a recording failed.
final class RecordingFailure extends AppFailure {
  const RecordingFailure([super.cause]);
}

/// A saved recording could not be decrypted or played.
final class PlaybackFailure extends AppFailure {
  const PlaybackFailure([super.cause]);
}

/// Practice reminders could not be scheduled or cancelled.
final class ReminderFailure extends AppFailure {
  const ReminderFailure([super.cause]);
}

/// A device sensor could not be started or read.
final class SensorFailure extends AppFailure {
  const SensorFailure([super.cause]);
}

/// Building or saving a CSV export failed.
final class ExportFailure extends AppFailure {
  const ExportFailure([super.cause]);
}

enum InputProblem {
  emailTaken,
  therapistRequired,
  exerciseNotApproved,
  consentRequired,
  instructionsRequired,
}

/// Input the user can correct.
final class InvalidInputFailure extends AppFailure {
  const InvalidInputFailure(this.problem);

  final InputProblem problem;
}
