import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../data/access_log_providers.dart';
import '../../domain/access_log.dart';

final accessLogProvider = FutureProvider<List<AccessLogEntry>>(
  (ref) => ref.watch(accessLogRepositoryProvider).recent(),
);

final accessLoggerProvider = Provider<AccessLogger>(AccessLogger.new);

/// Records an access by whoever is signed in.
class AccessLogger {
  AccessLogger(this._ref);

  final Ref _ref;

  Future<void> record(AccessAction action, String target) async {
    final user = _ref.read(authControllerProvider).value;
    if (user == null) return;
    await _ref
        .read(accessLogRepositoryProvider)
        .append(
          AccessLogEntry(
            at: DateTime.now(),
            userId: user.id,
            userEmail: user.email,
            action: action,
            target: target,
          ),
        );
    _ref.invalidate(accessLogProvider);
  }
}
