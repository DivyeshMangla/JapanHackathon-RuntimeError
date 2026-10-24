/// Optional permission for one child's media to leave the care service for
/// automated analysis. This does not alter their original signed care consent.
class HostedAnalysisPermission {
  const HostedAnalysisPermission({
    required this.provider,
    required this.allowed,
    required this.careConsentApproved,
    required this.localAnalysisAllowed,
    required this.disclosureVersion,
    required this.disclosureText,
    required this.privacyUrl,
    this.updatedAt,
  });

  final String provider;
  final bool allowed;
  final bool careConsentApproved;
  final bool localAnalysisAllowed;
  final String disclosureVersion;
  final String disclosureText;
  final String privacyUrl;
  final DateTime? updatedAt;
}

abstract interface class HostedAnalysisRepository {
  Future<HostedAnalysisPermission> permissionFor(String childId);

  Future<HostedAnalysisPermission> setPermission({
    required String childId,
    required bool allowed,
    required String disclosureVersion,
    required bool adultConfirmed,
  });
}
