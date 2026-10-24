/// Remembers which demo seed stages have run on this device.
abstract interface class SeedStateRepository {
  /// The last completed stage, or 0 on a fresh install.
  Future<int> version();

  Future<void> setVersion(int version);
}
