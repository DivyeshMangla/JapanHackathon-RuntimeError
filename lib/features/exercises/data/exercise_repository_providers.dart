import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/local_database.dart';
import '../domain/exercise_repositories.dart';
import '../domain/voice_use_entry.dart';
import 'hive_exercise_repositories.dart';
import 'hive_voice_diary_repository.dart';

final exerciseRepositoryProvider = Provider<ExerciseRepository>(
  (ref) => HiveExerciseRepository(ref.watch(localDatabaseProvider).exercises),
);

final scheduleRepositoryProvider = Provider<ScheduleRepository>(
  (ref) => HiveScheduleRepository(ref.watch(localDatabaseProvider).schedules),
);

final completionRepositoryProvider = Provider<CompletionRepository>(
  (ref) =>
      HiveCompletionRepository(ref.watch(localDatabaseProvider).completions),
);

final voiceDiaryRepositoryProvider = Provider<VoiceDiaryRepository>(
  (ref) =>
      HiveVoiceDiaryRepository(ref.watch(localDatabaseProvider).voiceDiary),
);
