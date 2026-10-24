import '../../../core/network/backend_client.dart';
import '../../../core/utils/dates.dart';
import '../domain/completion.dart';
import '../domain/exercise.dart';
import '../domain/exercise_repositories.dart';
import '../domain/schedule.dart';
import '../domain/voice_use_entry.dart';

class BackendExerciseRepository implements ExerciseRepository {
  BackendExerciseRepository(this._client);

  final BackendClient _client;

  @override
  Future<List<Exercise>> all() async {
    final response = await _client.get('/library');
    return response.objects('exercises').map(Exercise.fromMap).toList()
      ..sort((a, b) => a.title.compareTo(b.title));
  }

  @override
  Future<Exercise?> byId(String id) async {
    for (final exercise in await all()) {
      if (exercise.id == id) return exercise;
    }
    return null;
  }

  @override
  Future<void> save(Exercise exercise) async {
    await _client.put('/library/${exercise.id}', body: exercise.toMap());
  }
}

class BackendScheduleRepository implements ScheduleRepository {
  BackendScheduleRepository(this._client);

  final BackendClient _client;

  @override
  Future<List<Schedule>> forPatient(String patientId) async {
    final response = await _client.get('/patients/$patientId/assignments');
    return response.objects('assignments').map(Schedule.fromMap).toList();
  }

  @override
  Future<List<Schedule>> all() async {
    final response = await _client.get('/assignments');
    return response.objects('assignments').map(Schedule.fromMap).toList();
  }

  @override
  Future<void> save(Schedule schedule) async {
    await _client.put(
      '/patients/${schedule.patientId}/assignments/${schedule.id}',
      body: schedule.toMap(),
    );
  }

  @override
  Future<void> delete({required String patientId, required String id}) async {
    await _client.delete('/patients/$patientId/assignments/$id');
  }
}

class BackendCompletionRepository implements CompletionRepository {
  BackendCompletionRepository(this._client);

  final BackendClient _client;

  @override
  Future<List<Completion>> forPatient(
    String patientId, {
    required DateTime from,
    required DateTime to,
  }) async {
    final response = await _client.get(
      '/patients/$patientId/completions',
      query: {'from': _dayKey(from), 'to': _dayKey(to)},
    );
    return response.objects('completions').map(_completionFrom).toList();
  }

  @override
  Future<List<Completion>> all() async {
    final response = await _client.get('/completions');
    return response.objects('completions').map(_completionFrom).toList();
  }

  @override
  Future<void> add(Completion completion) async {
    await _client.put(
      '/patients/${completion.patientId}/completions/${completion.id}',
      body: {
        'exerciseId': completion.exerciseId,
        'day': _dayKey(completion.day),
        'completedAt': completion.completedAt.toUtc().toIso8601String(),
      },
    );
  }

  @override
  Future<void> delete({required String patientId, required String id}) async {
    await _client.delete('/patients/$patientId/completions/$id');
  }

  static String _dayKey(DateTime day) =>
      dateOnly(day).toIso8601String().substring(0, 10);

  static Completion _completionFrom(JsonObject json) => Completion(
    id: json['id']! as String,
    patientId: json['patientId']! as String,
    exerciseId: json['exerciseId']! as String,
    day: DateTime.parse(json['day']! as String),
    completedAt: DateTime.parse(json['completedAt']! as String).toLocal(),
  );
}

class BackendVoiceDiaryRepository implements VoiceDiaryRepository {
  BackendVoiceDiaryRepository(this._client);

  final BackendClient _client;

  @override
  Future<List<VoiceUseEntry>> forPatient(String patientId) async {
    final response = await _client.get('/patients/$patientId/diary');
    return _sorted(response.objects('entries').map(VoiceUseEntry.fromMap));
  }

  @override
  Future<List<VoiceUseEntry>> all() async {
    final response = await _client.get('/diary');
    return _sorted(response.objects('entries').map(VoiceUseEntry.fromMap));
  }

  @override
  Future<void> save(VoiceUseEntry entry) async {
    await _client.put(
      '/patients/${entry.patientId}/diary/${entry.id}',
      body: entry.toMap(),
    );
  }

  @override
  Future<void> delete({required String patientId, required String id}) async {
    await _client.delete('/patients/$patientId/diary/$id');
  }

  static List<VoiceUseEntry> _sorted(Iterable<VoiceUseEntry> entries) =>
      entries.toList()..sort((a, b) => a.loggedAt.compareTo(b.loggedAt));
}
