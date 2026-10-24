import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/local_database.dart';
import '../domain/analysis_service.dart';
import '../domain/recording_repository.dart';
import 'hive_recording_repository.dart';
import 'recording_files.dart';
import 'recording_vault.dart';

final recordingRepositoryProvider = Provider<RecordingRepository>(
  (ref) => HiveRecordingRepository(ref.watch(localDatabaseProvider).recordings),
);

final recordingVaultProvider = Provider<RecordingVault>(
  (ref) => RecordingVault(),
);

final recordingFilesProvider = Provider<RecordingFiles>(
  (ref) => RecordingFiles(ref.watch(recordingVaultProvider)),
);

final analysisServiceProvider = Provider<AnalysisService>(
  (ref) => const StubAnalysisService(),
);
