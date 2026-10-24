import 'package:hive_ce/hive_ce.dart';

import '../../../core/errors/guard.dart';
import '../domain/reminder.dart';

class HiveReminderRepository implements ReminderRepository {
  HiveReminderRepository(this._box);

  /// Minutes after midnight, keyed by user id.
  final Box<List<dynamic>> _box;

  @override
  Future<List<ReminderTime>> forUser(String userId) => guardStorage(
    () =>
        (_box.get(userId) ?? const [])
            .cast<int>()
            .map(ReminderTime.fromMinutes)
            .toList()
          ..sort(),
  );

  @override
  Future<void> save(String userId, List<ReminderTime> times) => guardStorage(
    () => _box.put(
      userId,
      (times.toSet().toList()..sort()).map((t) => t.minutes).toList(),
    ),
  );
}
