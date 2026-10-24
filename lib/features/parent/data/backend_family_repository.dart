import 'dart:convert';

import '../../../core/network/backend_client.dart';
import '../../auth/data/backend_user_repository.dart';
import '../../auth/domain/user.dart';
import '../domain/consent.dart';
import '../domain/family_repository.dart';

/// Children and their consent through the care service, which treats a
/// parent's signature as the approval.
class BackendFamilyRepository implements FamilyRepository {
  BackendFamilyRepository(this._client);

  final BackendClient _client;

  @override
  Future<ConsentForm> consentForm() async {
    final config = await _client.get('/config');
    return ConsentForm(
      version: config['consentVersion'] as String? ?? '',
      text: config['consentText'] as String? ?? '',
    );
  }

  @override
  Future<ChildConsent?> consentFor(String childId) async {
    final record = await _client.get('/patients/$childId');
    final consent = record['consent'];
    if (consent is! JsonObject || consent['status'] != 'approved') return null;
    final checks = consent['checks'];
    return ChildConsent(
      version: consent['version']! as String,
      signerName: consent['signer_name']! as String,
      signedAt: DateTime.parse(consent['signed_at']! as String).toLocal(),
      analysisAgreed: checks is JsonObject && checks['analysis'] == true,
    );
  }

  @override
  Future<User> addChild({
    required String childName,
    required String version,
    required String signerName,
    required Set<ConsentStatement> agreed,
    required List<int> signaturePng,
  }) async {
    final response = await _client.post(
      '/children',
      body: {
        'childName': childName.trim(),
        'consent': {
          'version': version,
          'signerName': signerName.trim(),
          'checks': {
            for (final statement in ConsentStatement.values)
              statement.name: agreed.contains(statement),
          },
          'signaturePng': base64Encode(signaturePng),
        },
      },
    );
    return userFromApi(response.object('user'));
  }
}
