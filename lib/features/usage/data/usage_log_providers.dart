import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/local_database.dart';
import '../domain/usage_event.dart';
import 'hive_usage_log_repository.dart';

final usageLogRepositoryProvider = Provider<UsageLogRepository>(
  (ref) => HiveUsageLogRepository(ref.watch(localDatabaseProvider).usageLog),
);
