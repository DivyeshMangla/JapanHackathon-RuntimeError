import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/backend_client.dart';
import '../domain/exercise_repositories.dart';
import '../domain/voice_use_entry.dart';
import 'backend_exercise_repositories.dart';

final exerciseRepositoryProvider = Provider<ExerciseRepository>(
  (ref) => BackendExerciseRepository(ref.watch(backendClientProvider)),
);

final scheduleRepositoryProvider = Provider<ScheduleRepository>(
  (ref) => BackendScheduleRepository(ref.watch(backendClientProvider)),
);

final completionRepositoryProvider = Provider<CompletionRepository>(
  (ref) => BackendCompletionRepository(ref.watch(backendClientProvider)),
);

final voiceDiaryRepositoryProvider = Provider<VoiceDiaryRepository>(
  (ref) => BackendVoiceDiaryRepository(ref.watch(backendClientProvider)),
);
