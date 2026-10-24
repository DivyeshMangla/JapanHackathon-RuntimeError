import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/backend_client.dart';
import '../domain/usage_event.dart';
import 'backend_usage_log_repository.dart';

final usageLogRepositoryProvider = Provider<UsageLogRepository>(
  (ref) => BackendUsageLogRepository(ref.watch(backendClientProvider)),
);
