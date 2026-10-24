import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_failure.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../auth/domain/user.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../data/usage_log_providers.dart';
import '../../domain/usage_event.dart';

/// A participant's usage log, newest first.
final usageLogProvider = FutureProvider.family<List<UsageEvent>, String>(
  (ref, patientId) =>
      ref.watch(usageLogRepositoryProvider).forPatient(patientId),
);

final usageLoggerProvider = Provider<UsageLogger>(UsageLogger.new);

/// Appends patient actions to the application usage log. Staff actions are
/// not usage of the patient app, so they are skipped.
class UsageLogger {
  UsageLogger(this._ref);

  final Ref _ref;

  /// [user] defaults to whoever is signed in; pass it when the auth state is
  /// about to change, as at sign-in and sign-out.
  Future<void> record(
    UsageAction action, {
    String detail = '',
    User? user,
  }) async {
    final patient = user ?? _ref.read(authControllerProvider).value;
    if (patient == null || patient.role != UserRole.patient) return;
    try {
      await _ref
          .read(usageLogRepositoryProvider)
          .append(
            UsageEvent(
              at: DateTime.now(),
              patientId: patient.id,
              action: action,
              detail: detail,
            ),
          );
      _ref.invalidate(usageLogProvider(patient.id));
    } on AppFailure catch (failure) {
      // The patient's action already succeeded; a missing log line must not
      // turn it into an error on screen.
      AppLogger.warning('Usage log write failed', failure);
    }
  }
}
