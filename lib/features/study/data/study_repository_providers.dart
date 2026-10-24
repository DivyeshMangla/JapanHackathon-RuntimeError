import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/local_database.dart';
import '../domain/monitoring_entry.dart';
import '../domain/participant_record.dart';
import 'hive_study_repositories.dart';

final participantRecordRepositoryProvider =
    Provider<ParticipantRecordRepository>(
      (ref) => HiveParticipantRecordRepository(
        ref.watch(localDatabaseProvider).participants,
      ),
    );

final monitoringRepositoryProvider = Provider<MonitoringRepository>(
  (ref) =>
      HiveMonitoringRepository(ref.watch(localDatabaseProvider).monitoring),
);
