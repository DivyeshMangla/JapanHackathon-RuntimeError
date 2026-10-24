import 'dart:convert';
import 'dart:typed_data';

/// Models for the connected care service. Each `fromJson` reads the API's
/// snake_case fields, so the wire format stops at this file.

enum ConnectedRole { admin, therapist, patient }

class ConnectedUser {
  const ConnectedUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
  });

  factory ConnectedUser.fromJson(Map<String, dynamic> json) => ConnectedUser(
    id: json['id'] as String,
    name: json['name'] as String,
    email: json['email'] as String,
    role: ConnectedRole.values.byName(json['role'] as String),
  );

  final String id;
  final String name;
  final String email;
  final ConnectedRole role;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    'role': role.name,
  };
}

class LibraryExercise {
  const LibraryExercise({
    required this.id,
    required this.name,
    required this.description,
    this.isMotor = false,
    this.minutes = 1,
    this.steps = const [],
    this.strokes = const [],
  });

  factory LibraryExercise.fromJson(Map<String, dynamic> json) =>
      LibraryExercise(
        id: json['id'] as String,
        name: json['name'] as String,
        description: json['description'] as String,
        isMotor: json['kind'] == 'motor',
        minutes: json['minutes'] as int? ?? 1,
        steps: List<String>.from(json['steps'] as List? ?? const []),
        strokes: [
          for (final stroke in json['strokes'] as List? ?? const [])
            [
              for (final point in stroke as List)
                [for (final value in point as List) (value as num).toDouble()],
            ],
        ],
      );

  final String id;
  final String name;
  final String description;
  final bool isMotor;
  final int minutes;
  final List<String> steps;
  final List<List<List<double>>> strokes;
}

class ConnectedConfig {
  const ConnectedConfig({
    required this.consentVersion,
    required this.consentText,
    required this.exercises,
  });

  factory ConnectedConfig.fromJson(Map<String, dynamic> json) =>
      ConnectedConfig(
        consentVersion: json['consentVersion'] as String? ?? '',
        consentText: json['consentText'] as String? ?? '',
        exercises: [
          for (final exercise in json['exercises'] as List? ?? const [])
            LibraryExercise.fromJson(exercise as Map<String, dynamic>),
        ],
      );

  static const empty = ConnectedConfig(
    consentVersion: '',
    consentText: '',
    exercises: [],
  );

  final String consentVersion;
  final String consentText;
  final List<LibraryExercise> exercises;

  LibraryExercise? exercise(String id) {
    for (final exercise in exercises) {
      if (exercise.id == id) return exercise;
    }
    return null;
  }
}

/// One statement on the connected consent form. The names are the keys the
/// server checks, so renaming a value breaks consent submission.
enum ConsentStatement {
  adult,
  participation,
  dataSharing,
  analysis;

  bool get isRequired => this != analysis;
}

enum ConsentStatus { missing, pending, approved }

class ConsentRecord {
  const ConsentRecord({
    required this.version,
    required this.signerName,
    required this.signedAt,
    required this.status,
    required this.analysisAgreed,
    required this.signaturePng,
  });

  factory ConsentRecord.fromJson(Map<String, dynamic> json) => ConsentRecord(
    version: json['version'] as String,
    signerName: json['signer_name'] as String,
    signedAt: DateTime.parse(json['signed_at'] as String),
    status: ConsentStatus.values.byName(json['status'] as String),
    analysisAgreed: (json['checks'] as Map)['analysis'] == true,
    signaturePng: base64Decode(json['signature_png'] as String),
  );

  final String version;
  final String signerName;
  final DateTime signedAt;
  final ConsentStatus status;
  final bool analysisAgreed;
  final Uint8List signaturePng;
}

class CarePlan {
  const CarePlan({
    required this.id,
    required this.title,
    required this.exerciseIds,
    required this.sessionsPerDay,
    required this.notes,
  });

  factory CarePlan.fromJson(Map<String, dynamic> json) => CarePlan(
    id: json['id'] as String,
    title: json['title'] as String,
    exerciseIds: List<String>.unmodifiable(json['exercises'] as List),
    sessionsPerDay: json['sessions_per_day'] as int,
    notes: json['notes'] as String? ?? '',
  );

  final String id;
  final String title;
  final List<String> exerciseIds;
  final int sessionsPerDay;
  final String notes;
}

/// What a therapist prescribes; the server assigns the id.
class PlanDraft {
  const PlanDraft({
    required this.title,
    required this.exerciseIds,
    required this.sessionsPerDay,
    required this.notes,
  });

  final String title;
  final List<String> exerciseIds;
  final int sessionsPerDay;
  final String notes;
}

class ClinicalForms {
  const ClinicalForms({
    required this.age,
    required this.demographic,
    required this.clinical,
  });

  factory ClinicalForms.fromJson(Map<String, dynamic> json) => ClinicalForms(
    age: json['age'] as int,
    demographic: json['demographic'] as String,
    clinical: json['clinical'] as String,
  );

  final int age;
  final String demographic;
  final String clinical;
}

class PracticeEntry {
  const PracticeEntry({
    required this.exerciseId,
    required this.minutes,
    required this.completedAt,
  });

  factory PracticeEntry.fromJson(Map<String, dynamic> json) => PracticeEntry(
    exerciseId: json['exercise_id'] as String,
    minutes: json['minutes'] as int,
    completedAt: DateTime.parse(json['completed_at'] as String),
  );

  final String exerciseId;
  final int minutes;
  final DateTime completedAt;
}

class RecordingSummary {
  const RecordingSummary({
    required this.id,
    required this.exerciseId,
    required this.durationSeconds,
    required this.createdAt,
    required this.reviewNote,
  });

  factory RecordingSummary.fromJson(Map<String, dynamic> json) =>
      RecordingSummary(
        id: json['id'] as String,
        exerciseId: json['exercise_id'] as String,
        durationSeconds: json['duration_seconds'] as int,
        createdAt: DateTime.parse(json['created_at'] as String),
        reviewNote: json['review_note'] as String?,
      );

  final String id;
  final String exerciseId;
  final int durationSeconds;
  final DateTime createdAt;
  final String? reviewNote;
}

class PatientSummary {
  const PatientSummary({
    required this.id,
    required this.name,
    required this.therapistAssigned,
    required this.consentStatus,
    required this.activeDays,
    required this.sessions,
    required this.minutes,
  });

  factory PatientSummary.fromJson(Map<String, dynamic> json) => PatientSummary(
    id: json['id'] as String,
    name: json['name'] as String,
    therapistAssigned: json['therapist_id'] != null,
    consentStatus: ConsentStatus.values.byName(
      json['consent_status'] as String? ?? ConsentStatus.missing.name,
    ),
    activeDays: json['active_days'] as int? ?? 0,
    sessions: json['sessions'] as int? ?? 0,
    minutes: json['minutes'] as int? ?? 0,
  );

  final String id;
  final String name;
  final bool therapistAssigned;
  final ConsentStatus consentStatus;

  /// Days with any practice in the last seven.
  final int activeDays;
  final int sessions;
  final int minutes;
}

/// Everything one patient's screens show, as the server returns it.
class PatientRecord {
  const PatientRecord({
    required this.summary,
    required this.consent,
    required this.plan,
    required this.forms,
    required this.practice,
    required this.recordings,
    this.motorSubmissions = const [],
  });

  factory PatientRecord.fromJson(Map<String, dynamic> json) => PatientRecord(
    summary: PatientSummary.fromJson(json['patient'] as Map<String, dynamic>),
    consent: json['consent'] == null
        ? null
        : ConsentRecord.fromJson(json['consent'] as Map<String, dynamic>),
    plan: json['plan'] == null
        ? null
        : CarePlan.fromJson(json['plan'] as Map<String, dynamic>),
    forms: json['forms'] == null
        ? null
        : ClinicalForms.fromJson(json['forms'] as Map<String, dynamic>),
    practice: [
      for (final entry in json['progress'] as List? ?? const [])
        PracticeEntry.fromJson(entry as Map<String, dynamic>),
    ],
    motorSubmissions: [
      for (final entry in json['motorSubmissions'] as List? ?? const [])
        MotorSubmission.fromJson(entry as Map<String, dynamic>),
    ],
    recordings: [
      for (final recording in json['recordings'] as List? ?? const [])
        RecordingSummary.fromJson(recording as Map<String, dynamic>),
    ],
  );

  final PatientSummary summary;
  final ConsentRecord? consent;
  final CarePlan? plan;
  final ClinicalForms? forms;
  final List<PracticeEntry> practice;
  final List<RecordingSummary> recordings;
  final List<MotorSubmission> motorSubmissions;
}

/// A self-registration request. Therapists also give their clinic and
/// registration number, and wait for an administrator's approval.
class Registration {
  const Registration({
    required this.role,
    required this.name,
    required this.email,
    required this.password,
    this.clinic = '',
    this.registrationNumber = '',
  });

  final ConnectedRole role;
  final String name;
  final String email;
  final String password;
  final String clinic;
  final String registrationNumber;
}

enum OutboxKind { progress, recordings }

/// A practice log or recording saved on the phone and not yet uploaded.
class OutboxItem {
  const OutboxItem({
    required this.id,
    required this.kind,
    required this.planId,
    required this.exerciseId,
  });

  final String id;
  final OutboxKind kind;
  final String planId;
  final String exerciseId;
}

class MotorReport {
  const MotorReport({
    required this.observations,
    required this.suggestion,
    required this.alignment,
    required this.formation,
    required this.spacing,
    required this.model,
    required this.imageQuality,
  });
  factory MotorReport.fromJson(Map<String, dynamic> json) => MotorReport(
    observations: json['observations'] as String,
    suggestion: json['suggestion'] as String,
    alignment: json['alignment'] as String,
    formation: json['formation'] as String,
    spacing: json['spacing'] as String,
    model: json['model'] as String,
    imageQuality: json['imageQuality'] as String,
  );
  final String observations,
      suggestion,
      alignment,
      formation,
      spacing,
      model,
      imageQuality;
}

class MotorSubmission {
  const MotorSubmission({
    required this.id,
    required this.exerciseId,
    required this.practiceDay,
    required this.status,
    required this.createdAt,
    this.report,
    this.reviewNote,
  });
  factory MotorSubmission.fromJson(Map<String, dynamic> json) =>
      MotorSubmission(
        id: json['id'] as String,
        exerciseId: json['exercise_id'] as String,
        practiceDay: json['practice_day'] as String,
        status: json['analysis_status'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
        report: json['report'] == null
            ? null
            : MotorReport.fromJson(json['report'] as Map<String, dynamic>),
        reviewNote: json['review_note'] as String?,
      );
  final String id, exerciseId, practiceDay, status;
  final DateTime createdAt;
  final MotorReport? report;
  final String? reviewNote;
}
