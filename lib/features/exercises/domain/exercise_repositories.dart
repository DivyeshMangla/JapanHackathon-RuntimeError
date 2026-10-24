import 'completion.dart';
import 'exercise.dart';
import 'schedule.dart';

abstract interface class ExerciseRepository {
  Future<List<Exercise>> all();

  Future<Exercise?> byId(String id);

  Future<void> save(Exercise exercise);
}

abstract interface class ScheduleRepository {
  /// Every version, current and past.
  Future<List<Schedule>> forPatient(String patientId);

  /// Every version for every patient, for export.
  Future<List<Schedule>> all();

  Future<void> save(Schedule schedule);

  Future<void> delete({required String patientId, required String id});
}

abstract interface class CompletionRepository {
  /// Completions whose day falls in [from, to] inclusive.
  Future<List<Completion>> forPatient(
    String patientId, {
    required DateTime from,
    required DateTime to,
  });

  /// Every completion, for export.
  Future<List<Completion>> all();

  Future<void> add(Completion completion);

  Future<void> delete({required String patientId, required String id});
}
