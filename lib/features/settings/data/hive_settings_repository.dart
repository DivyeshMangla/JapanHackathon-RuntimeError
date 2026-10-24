import 'package:hive_ce/hive_ce.dart';

import '../../../core/errors/guard.dart';
import '../domain/study_settings.dart';

class HiveSettingsRepository implements SettingsRepository {
  HiveSettingsRepository(this._meta);

  static const _key = 'study.settings';

  final Box<Object> _meta;

  @override
  Future<StudySettings> load() => guardStorage(() async {
    final map = _meta.get(_key) as Map<dynamic, dynamic>?;
    return map == null ? const StudySettings() : StudySettings.fromMap(map);
  });

  @override
  Future<void> save(StudySettings settings) =>
      guardStorage(() => _meta.put(_key, settings.toMap()));
}
