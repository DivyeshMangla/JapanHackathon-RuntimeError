import 'package:hive_ce/hive_ce.dart';

import '../../../core/errors/guard.dart';
import '../domain/access_log.dart';

class HiveAccessLogRepository implements AccessLogRepository {
  HiveAccessLogRepository(this._box);

  /// Entries keyed by Hive's auto-increment integers, so order is append
  /// order and existing keys are never reused.
  final Box<Map<dynamic, dynamic>> _box;

  @override
  Future<void> append(AccessLogEntry entry) =>
      guardStorage(() => _box.add(entry.toMap()));

  @override
  Future<List<AccessLogEntry>> recent({int limit = 200}) =>
      guardStorage(() async {
        final values = _box.values.toList();
        final start = values.length > limit ? values.length - limit : 0;
        return [
          for (final map in values.sublist(start).reversed)
            AccessLogEntry.fromMap(map),
        ];
      });
}
