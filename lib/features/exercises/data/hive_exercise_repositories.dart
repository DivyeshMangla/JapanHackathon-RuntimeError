import 'package:hive_ce/hive_ce.dart';

import '../../../core/errors/guard.dart';
import '../../../core/utils/dates.dart';
import '../domain/completion.dart';
import '../domain/exercise.dart';
import '../domain/exercise_repositories.dart';
import '../domain/schedule.dart';

class HiveExerciseRepository implements ExerciseRepository {
  HiveExerciseRepository(this._box);

  final Box<Map<dynamic, dynamic>> _box;

  @override
  Future<List<Exercise>> all() => guardStorage(
    () =>
        _box.values.map(Exercise.fromMap).toList()
          ..sort((a, b) => a.title.compareTo(b.title)),
  );

  @override
  Future<Exercise?> byId(String id) => guardStorage(() async {
    final map = _box.get(id);
    return map == null ? null : Exercise.fromMap(map);
  });

  @override
  Future<void> save(Exercise exercise) =>
      guardStorage(() => _box.put(exercise.id, exercise.toMap()));
}

class HiveScheduleRepository implements ScheduleRepository {
  HiveScheduleRepository(this._box);

  final Box<Map<dynamic, dynamic>> _box;

  @override
  Future<List<Schedule>> forPatient(String patientId) => guardStorage(
    () => _box.values
        .where((m) => m['patientId'] == patientId)
        .map(Schedule.fromMap)
        .toList(),
  );

  @override
  Future<List<Schedule>> all() =>
      guardStorage(() => _box.values.map(Schedule.fromMap).toList());

  @override
  Future<void> save(Schedule schedule) =>
      guardStorage(() => _box.put(schedule.id, schedule.toMap()));

  @override
  Future<void> delete(String id) => guardStorage(() => _box.delete(id));
}

class HiveCompletionRepository implements CompletionRepository {
  HiveCompletionRepository(this._box);

  final Box<Map<dynamic, dynamic>> _box;

  @override
  Future<List<Completion>> forPatient(
    String patientId, {
    required DateTime from,
    required DateTime to,
  }) => guardStorage(() async {
    final start = dateOnly(from);
    final end = dateOnly(to);
    return _box.values
        .where((m) => m['patientId'] == patientId)
        .map(Completion.fromMap)
        .where((c) => !c.day.isBefore(start) && !c.day.isAfter(end))
        .toList();
  });

  @override
  Future<List<Completion>> all() =>
      guardStorage(() => _box.values.map(Completion.fromMap).toList());

  @override
  Future<void> add(Completion completion) =>
      guardStorage(() => _box.put(completion.id, completion.toMap()));

  @override
  Future<void> delete(String id) => guardStorage(() => _box.delete(id));
}
