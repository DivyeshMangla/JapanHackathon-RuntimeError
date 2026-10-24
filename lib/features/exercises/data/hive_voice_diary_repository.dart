import 'package:hive_ce/hive_ce.dart';

import '../../../core/errors/guard.dart';
import '../domain/voice_use_entry.dart';

class HiveVoiceDiaryRepository implements VoiceDiaryRepository {
  HiveVoiceDiaryRepository(this._box);

  final Box<Map<dynamic, dynamic>> _box;

  @override
  Future<List<VoiceUseEntry>> forPatient(String patientId) => guardStorage(
    () => _sorted(
      _box.values
          .where((m) => m['patientId'] == patientId)
          .map(VoiceUseEntry.fromMap),
    ),
  );

  @override
  Future<List<VoiceUseEntry>> all() =>
      guardStorage(() => _sorted(_box.values.map(VoiceUseEntry.fromMap)));

  @override
  Future<void> save(VoiceUseEntry entry) =>
      guardStorage(() => _box.put(entry.id, entry.toMap()));

  @override
  Future<void> delete(String id) => guardStorage(() => _box.delete(id));

  static List<VoiceUseEntry> _sorted(Iterable<VoiceUseEntry> entries) =>
      entries.toList()..sort((a, b) => a.loggedAt.compareTo(b.loggedAt));
}
