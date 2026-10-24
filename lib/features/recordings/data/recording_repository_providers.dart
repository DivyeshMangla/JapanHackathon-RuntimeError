import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/backend_client.dart';
import '../domain/analysis_service.dart';
import '../domain/recording_repository.dart';
import 'backend_recording_repository.dart';
import 'playback_files.dart';
import 'recording_files.dart';

final recordingRepositoryProvider = Provider<RecordingRepository>(
  (ref) => BackendRecordingRepository(ref.watch(backendClientProvider)),
);

final playbackFilesProvider = Provider<PlaybackFiles>(
  (ref) => const PlaybackFiles(),
);

final recordingFilesProvider = Provider<RecordingFiles>(
  (ref) => const RecordingFiles(),
);

final analysisServiceProvider = Provider<AnalysisService>(
  (ref) => const StubAnalysisService(),
);
