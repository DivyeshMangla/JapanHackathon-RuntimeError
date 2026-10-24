import 'package:hive_ce/hive_ce.dart';

import '../../../core/errors/guard.dart';
import '../domain/usage_event.dart';

class HiveUsageLogRepository implements UsageLogRepository {
  HiveUsageLogRepository(this._box);

  /// Entries keyed by Hive's auto-increment integers, so order is append
  /// order and keys are never reused.
  final Box<Map<dynamic, dynamic>> _box;

  @override
  Future<void> append(UsageEvent event) =>
      guardStorage(() => _box.add(event.toMap()));

  @override
  Future<List<UsageEvent>> forPatient(String patientId) => guardStorage(
    () => [
      for (final map in _box.values.toList().reversed)
        if (map['patientId'] == patientId) UsageEvent.fromMap(map),
    ],
  );

  @override
  Future<List<UsageEvent>> all() =>
      guardStorage(() => _box.values.map(UsageEvent.fromMap).toList());
}
