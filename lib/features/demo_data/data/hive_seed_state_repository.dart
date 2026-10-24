import 'package:hive_ce/hive_ce.dart';

import '../../../core/errors/guard.dart';
import '../domain/seed_state_repository.dart';

class HiveSeedStateRepository implements SeedStateRepository {
  HiveSeedStateRepository(this._meta);

  static const _key = 'seed.version';

  final Box<Object> _meta;

  @override
  Future<int> version() => guardStorage(() => _meta.get(_key) as int? ?? 0);

  @override
  Future<void> setVersion(int version) =>
      guardStorage(() => _meta.put(_key, version));
}
