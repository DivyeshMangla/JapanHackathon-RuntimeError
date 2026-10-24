import '../../../core/network/backend_client.dart';
import '../domain/usage_event.dart';

/// Patient actions, kept on the care service so staff on other phones see
/// them. Writes are append-only.
class BackendUsageLogRepository implements UsageLogRepository {
  BackendUsageLogRepository(this._client);

  final BackendClient _client;

  @override
  Future<void> append(UsageEvent event) async {
    await _client.post(
      '/patients/${event.patientId}/usage',
      body: event.toMap(),
    );
  }

  @override
  Future<List<UsageEvent>> forPatient(String patientId) async {
    final response = await _client.get('/patients/$patientId/usage');
    return response
        .objects('events')
        .map(UsageEvent.fromMap)
        .toList()
        .reversed
        .toList();
  }

  @override
  Future<List<UsageEvent>> all() async {
    final response = await _client.get('/usage');
    return response.objects('events').map(UsageEvent.fromMap).toList();
  }
}
