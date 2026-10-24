import 'package:hive_ce/hive_ce.dart';

import '../../../core/errors/guard.dart';
import '../domain/recording.dart';
import '../domain/recording_repository.dart';

class HiveRecordingRepository implements RecordingRepository {
  HiveRecordingRepository(this._box);

  final Box<Map<dynamic, dynamic>> _box;

  @override
  Future<List<Recording>> forPatient(String patientId) => guardStorage(
    () =>
        _box.values
            .where((m) => m['patientId'] == patientId)
            .map(Recording.fromMap)
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
  );

  @override
  Future<List<Recording>> all() => guardStorage(
    () =>
        _box.values.map(Recording.fromMap).toList()
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt)),
  );

  @override
  Future<void> save(Recording recording) =>
      guardStorage(() => _box.put(recording.id, recording.toMap()));
}
