import '../../../core/network/backend_client.dart';
import '../domain/hosted_analysis.dart';

class BackendHostedAnalysisRepository implements HostedAnalysisRepository {
  BackendHostedAnalysisRepository(this._client);

  final BackendClient _client;

  HostedAnalysisPermission _decode(JsonObject data) {
    final disclosure = data.object('disclosure');
    return HostedAnalysisPermission(
      provider: data['provider'] as String,
      allowed: data['allowed'] == true,
      careConsentApproved: data['careConsentApproved'] == true,
      localAnalysisAllowed: data['localAnalysisAllowed'] == true,
      disclosureVersion: data['disclosureVersion'] as String,
      disclosureText: disclosure['text'] as String,
      privacyUrl: disclosure['privacyUrl'] as String,
      updatedAt: data['updatedAt'] is String
          ? DateTime.tryParse(data['updatedAt'] as String)?.toLocal()
          : null,
    );
  }

  @override
  Future<HostedAnalysisPermission> permissionFor(String childId) async =>
      _decode(
        await _client.get(
          '/patients/${Uri.encodeComponent(childId)}/hosted-analysis',
        ),
      );

  @override
  Future<HostedAnalysisPermission> setPermission({
    required String childId,
    required bool allowed,
    required String disclosureVersion,
    required bool adultConfirmed,
  }) async => _decode(
    await _client.put(
      '/patients/${Uri.encodeComponent(childId)}/hosted-analysis',
      body: {
        'allowed': allowed,
        'disclosureVersion': disclosureVersion,
        'adultConfirmed': adultConfirmed,
      },
    ),
  );
}
