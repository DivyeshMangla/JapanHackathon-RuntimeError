import '../../auth/domain/user.dart';
import 'consent.dart';

abstract interface class FamilyRepository {
  Future<ConsentForm> consentForm();

  /// The consent signed when the child was added, or null when there is
  /// none. It never expires, whatever its version.
  Future<ChildConsent?> consentFor(String childId);

  /// Creates the parent's child together with the signed consent, which is
  /// only ever asked for here.
  Future<User> addChild({
    required String childName,
    required String version,
    required String signerName,
    required Set<ConsentStatement> agreed,
    required List<int> signaturePng,
  });
}
