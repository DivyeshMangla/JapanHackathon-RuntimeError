import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/local_database.dart';
import '../domain/access_log.dart';
import 'hive_access_log_repository.dart';

final accessLogRepositoryProvider = Provider<AccessLogRepository>(
  (ref) => HiveAccessLogRepository(ref.watch(localDatabaseProvider).accessLog),
);
