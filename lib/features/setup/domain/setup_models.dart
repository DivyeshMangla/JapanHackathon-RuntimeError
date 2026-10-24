import 'dart:typed_data';

/// One item of the study consent form. The name is also the key in signed
/// consent records, so renaming a value breaks existing signatures.
enum ConsentItem {
  participation,
  demographics,
  voice,
  therapist,
  hospital,
  adult,
  analysis;

  /// Only anonymised analysis may be declined.
  bool get isRequired => this != analysis;
}

/// A therapist's public profile: the device's own on a therapist phone, or
/// the linked therapist on a patient phone.
class TherapistProfile {
  const TherapistProfile({
    required this.id,
    required this.name,
    required this.clinic,
  });

  final String id;
  final String name;
  final String clinic;
}

/// The consent a patient signed, as the therapist reviews it.
class ConsentSummary {
  ConsentSummary({
    required this.version,
    required this.signedAt,
    required this.locale,
    required Map<ConsentItem, bool> checks,
    required this.signaturePng,
  }) : checks = Map.unmodifiable(checks);

  final String version;
  final DateTime signedAt;
  final String locale;
  final Map<ConsentItem, bool> checks;
  final Uint8List signaturePng;
}

enum SetupPatientStatus { pending, approved, planReady }

/// A patient on the therapist phone, from imported consent to sent plan.
class SetupPatient {
  const SetupPatient({
    required this.id,
    required this.status,
    required this.consent,
    required this.hasForms,
    required this.hasPlan,
  });

  final String id;
  final SetupPatientStatus status;
  final ConsentSummary consent;
  final bool hasForms;
  final bool hasPlan;

  /// The therapist has countersigned, so forms may be collected.
  bool get isApproved => status != SetupPatientStatus.pending;
}

/// The demographic and clinical forms a therapist collects after approval.
class ParticipantForms {
  const ParticipantForms({
    required this.age,
    required this.demographic,
    required this.clinical,
  });

  final int age;
  final String demographic;
  final String clinical;
}
