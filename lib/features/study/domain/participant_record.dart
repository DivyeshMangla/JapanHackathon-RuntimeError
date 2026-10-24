import '../../../core/utils/dates.dart';

enum Gender { female, male, other, preferNotToSay }

enum EducationLevel {
  noFormal,
  primary,
  secondary,
  higherSecondary,
  graduate,
  postgraduate,
}

/// Koufman and Isaacson's voice-user levels, the usual way voice clinics
/// describe how much a person's work depends on their voice.
enum VoiceUseLevel {
  eliteVocal,
  professionalVocal,
  nonVocalProfessional,
  nonVocalNonProfessional,
}

enum SmokingStatus { never, former, current }

/// The Demographic part of the Demographic and Clinical Information Form.
/// Age is stored instead of a date of birth to keep the record less
/// identifying.
class Demographics {
  const Demographics({
    required this.ageYears,
    required this.gender,
    required this.education,
    required this.occupation,
    required this.voiceUse,
    required this.primaryLanguage,
  });

  final int ageYears;
  final Gender gender;
  final EducationLevel education;
  final String occupation;
  final VoiceUseLevel voiceUse;
  final String primaryLanguage;

  Map<String, Object?> toMap() => {
    'ageYears': ageYears,
    'gender': gender.name,
    'education': education.name,
    'occupation': occupation,
    'voiceUse': voiceUse.name,
    'primaryLanguage': primaryLanguage,
  };

  factory Demographics.fromMap(Map<dynamic, dynamic> map) => Demographics(
    ageYears: map['ageYears'] as int,
    gender: Gender.values.byName(map['gender'] as String),
    education: EducationLevel.values.byName(map['education'] as String),
    occupation: map['occupation'] as String,
    voiceUse: VoiceUseLevel.values.byName(map['voiceUse'] as String),
    primaryLanguage: map['primaryLanguage'] as String,
  );
}

/// The Clinical part of the Demographic and Clinical Information Form.
class ClinicalDetails {
  const ClinicalDetails({
    required this.diagnosis,
    required this.symptomMonths,
    required this.smoking,
    this.laryngoscopyOn,
    this.therapyStartedOn,
    this.clinicSessionsPerWeek,
    this.otherConditions = '',
  });

  /// As written by the clinician, e.g. "Bilateral vocal fold nodules".
  final String diagnosis;

  /// How long the voice problem has lasted, in months.
  final int symptomMonths;
  final SmokingStatus smoking;
  final DateTime? laryngoscopyOn;

  /// When routine voice therapy began, which can precede app use.
  final DateTime? therapyStartedOn;

  /// In-clinic therapy sessions per week alongside the app.
  final int? clinicSessionsPerWeek;
  final String otherConditions;

  Map<String, Object?> toMap() => {
    'diagnosis': diagnosis,
    'symptomMonths': symptomMonths,
    'smoking': smoking.name,
    'laryngoscopyOn': laryngoscopyOn?.toIso8601String(),
    'therapyStartedOn': therapyStartedOn?.toIso8601String(),
    'clinicSessionsPerWeek': clinicSessionsPerWeek,
    'otherConditions': otherConditions,
  };

  factory ClinicalDetails.fromMap(Map<dynamic, dynamic> map) {
    DateTime? date(String key) {
      final value = map[key] as String?;
      return value == null ? null : DateTime.parse(value);
    }

    return ClinicalDetails(
      diagnosis: map['diagnosis'] as String,
      symptomMonths: map['symptomMonths'] as int,
      smoking: SmokingStatus.values.byName(map['smoking'] as String),
      laryngoscopyOn: date('laryngoscopyOn'),
      therapyStartedOn: date('therapyStartedOn'),
      clinicSessionsPerWeek: map['clinicSessionsPerWeek'] as int?,
      otherConditions: map['otherConditions'] as String? ?? '',
    );
  }
}

/// A participant's study enrolment: consent, baseline forms, orientation,
/// intervention start and any withdrawal. One per patient.
class ParticipantRecord {
  const ParticipantRecord({
    required this.patientId,
    required this.interventionStart,
    this.infoSheetProvided = false,
    this.consentSignedOn,
    this.demographics,
    this.clinical,
    this.orientationOn,
    this.withdrawnOn,
    this.withdrawalReason = '',
  });

  /// The record assumed for a patient enrolled before records existed:
  /// nothing documented, intervention starting on the account's creation.
  factory ParticipantRecord.undocumented({
    required String patientId,
    required DateTime enrolledOn,
  }) => ParticipantRecord(
    patientId: patientId,
    interventionStart: dateOnly(enrolledOn),
  );

  final String patientId;

  /// First day of app use, which anchors the study weeks and probe schedule.
  final DateTime interventionStart;

  /// The Participant Information Sheet was given and explained.
  final bool infoSheetProvided;

  /// Date on the signed Written Consent Form, kept on paper.
  final DateTime? consentSignedOn;
  final Demographics? demographics;
  final ClinicalDetails? clinical;

  /// When the therapist walked the participant through the app.
  final DateTime? orientationOn;
  final DateTime? withdrawnOn;
  final String withdrawalReason;

  bool get hasConsent => infoSheetProvided && consentSignedOn != null;

  bool get isWithdrawn => withdrawnOn != null;

  ParticipantRecord copyWith({
    DateTime? interventionStart,
    bool? infoSheetProvided,
    DateTime? consentSignedOn,
    Demographics? demographics,
    ClinicalDetails? clinical,
    DateTime? orientationOn,
  }) => ParticipantRecord(
    patientId: patientId,
    interventionStart: interventionStart ?? this.interventionStart,
    infoSheetProvided: infoSheetProvided ?? this.infoSheetProvided,
    consentSignedOn: consentSignedOn ?? this.consentSignedOn,
    demographics: demographics ?? this.demographics,
    clinical: clinical ?? this.clinical,
    orientationOn: orientationOn ?? this.orientationOn,
    withdrawnOn: withdrawnOn,
    withdrawalReason: withdrawalReason,
  );

  ParticipantRecord withdraw({required DateTime on, required String reason}) =>
      ParticipantRecord(
        patientId: patientId,
        interventionStart: interventionStart,
        infoSheetProvided: infoSheetProvided,
        consentSignedOn: consentSignedOn,
        demographics: demographics,
        clinical: clinical,
        orientationOn: orientationOn,
        withdrawnOn: dateOnly(on),
        withdrawalReason: reason,
      );

  Map<String, Object?> toMap() => {
    'patientId': patientId,
    'interventionStart': interventionStart.toIso8601String(),
    'infoSheetProvided': infoSheetProvided,
    'consentSignedOn': consentSignedOn?.toIso8601String(),
    'demographics': demographics?.toMap(),
    'clinical': clinical?.toMap(),
    'orientationOn': orientationOn?.toIso8601String(),
    'withdrawnOn': withdrawnOn?.toIso8601String(),
    'withdrawalReason': withdrawalReason,
  };

  factory ParticipantRecord.fromMap(Map<dynamic, dynamic> map) {
    DateTime? date(String key) {
      final value = map[key] as String?;
      return value == null ? null : DateTime.parse(value);
    }

    final demographics = map['demographics'] as Map<dynamic, dynamic>?;
    final clinical = map['clinical'] as Map<dynamic, dynamic>?;
    return ParticipantRecord(
      patientId: map['patientId'] as String,
      interventionStart: DateTime.parse(map['interventionStart'] as String),
      infoSheetProvided: map['infoSheetProvided'] as bool? ?? false,
      consentSignedOn: date('consentSignedOn'),
      demographics: demographics == null
          ? null
          : Demographics.fromMap(demographics),
      clinical: clinical == null ? null : ClinicalDetails.fromMap(clinical),
      orientationOn: date('orientationOn'),
      withdrawnOn: date('withdrawnOn'),
      withdrawalReason: map['withdrawalReason'] as String? ?? '',
    );
  }
}

abstract interface class ParticipantRecordRepository {
  Future<ParticipantRecord?> forPatient(String patientId);

  Future<List<ParticipantRecord>> all();

  Future<void> save(ParticipantRecord record);
}
