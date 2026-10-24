/// One statement on the care consent. The names are the keys the care
/// service checks, so renaming a value breaks consent submission.
enum ConsentStatement {
  adult,
  participation,
  dataSharing,
  analysis;

  bool get isRequired => this != analysis;
}

/// The consent text the care service currently asks parents to sign.
class ConsentForm {
  const ConsentForm({required this.version, required this.text});

  final String version;
  final String text;
}

/// A parent's signed consent for one child.
class ChildConsent {
  const ChildConsent({
    required this.version,
    required this.signerName,
    required this.signedAt,
    required this.analysisAgreed,
  });

  final String version;
  final String signerName;
  final DateTime signedAt;
  final bool analysisAgreed;
}
