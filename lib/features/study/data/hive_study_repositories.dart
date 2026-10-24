import 'package:hive_ce/hive_ce.dart';

import '../../../core/errors/guard.dart';
import '../domain/monitoring_entry.dart';
import '../domain/participant_record.dart';

class HiveParticipantRecordRepository implements ParticipantRecordRepository {
  HiveParticipantRecordRepository(this._box);

  final Box<Map<dynamic, dynamic>> _box;

  @override
  Future<ParticipantRecord?> forPatient(String patientId) =>
      guardStorage(() async {
        final map = _box.get(patientId);
        return map == null ? null : ParticipantRecord.fromMap(map);
      });

  @override
  Future<List<ParticipantRecord>> all() =>
      guardStorage(() => _box.values.map(ParticipantRecord.fromMap).toList());

  @override
  Future<void> save(ParticipantRecord record) =>
      guardStorage(() => _box.put(record.patientId, record.toMap()));
}

class HiveMonitoringRepository implements MonitoringRepository {
  HiveMonitoringRepository(this._box);

  final Box<Map<dynamic, dynamic>> _box;

  @override
  Future<List<MonitoringEntry>> forPatient(String patientId) => guardStorage(
    () => _sorted(
      _box.values
          .where((m) => m['patientId'] == patientId)
          .map(MonitoringEntry.fromMap),
    ),
  );

  @override
  Future<List<MonitoringEntry>> all() =>
      guardStorage(() => _sorted(_box.values.map(MonitoringEntry.fromMap)));

  @override
  Future<void> save(MonitoringEntry entry) =>
      guardStorage(() => _box.put(entry.id, entry.toMap()));

  static List<MonitoringEntry> _sorted(Iterable<MonitoringEntry> entries) =>
      entries.toList()..sort((a, b) {
        final byWeek = a.week.compareTo(b.week);
        return byWeek != 0 ? byWeek : a.recordedAt.compareTo(b.recordedAt);
      });
}
