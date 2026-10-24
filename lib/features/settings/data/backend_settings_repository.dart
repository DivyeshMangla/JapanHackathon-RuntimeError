import '../../../core/network/backend_client.dart';
import '../domain/study_settings.dart';

/// Settings an administrator sets once for every phone.
class BackendSettingsRepository implements SettingsRepository {
  BackendSettingsRepository(this._client);

  final BackendClient _client;

  @override
  Future<StudySettings> load() async {
    final response = await _client.get('/study-settings');
    final stored = response['settings'];
    return stored is JsonObject
        ? StudySettings.fromMap(stored)
        : const StudySettings();
  }

  @override
  Future<void> save(StudySettings settings) async {
    await _client.put('/study-settings', body: settings.toMap());
  }
}
