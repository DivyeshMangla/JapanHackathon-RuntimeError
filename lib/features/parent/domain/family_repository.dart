import '../../auth/domain/user.dart';
import 'consent.dart';

abstract interface class FamilyRepository {
  Future<ConsentForm> consentForm();

  /// The child's current approved consent, or null when none is signed for
  /// the current version.
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
