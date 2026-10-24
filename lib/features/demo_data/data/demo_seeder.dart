import 'dart:isolate';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/local_database.dart';
import '../../../core/utils/dates.dart';
import '../../auth/data/auth_repository_providers.dart';
import '../../auth/domain/auth_repository.dart';
import '../../auth/domain/user.dart';
import '../../auth/domain/user_repository.dart';
import '../../exercises/data/exercise_repository_providers.dart';
import '../../exercises/domain/exercise_repositories.dart';
import '../../questionnaires/data/questionnaire_repository_providers.dart';
import '../../questionnaires/domain/questionnaire.dart';
import '../../recordings/data/recording_files.dart';
import '../../recordings/data/recording_repository_providers.dart';
import '../../recordings/domain/recording.dart';
import '../../recordings/domain/recording_repository.dart';
import '../../reminders/data/reminder_repository_providers.dart';
import '../../reminders/domain/reminder.dart';
import '../../study/data/study_repository_providers.dart';
import '../../study/domain/monitoring_entry.dart';
import '../../study/domain/participant_record.dart';
import '../../usage/data/usage_log_providers.dart';
import '../../usage/domain/usage_event.dart';
import '../domain/seed_state_repository.dart';
import 'demo_program.dart';
import 'demo_study.dart';
import 'hive_seed_state_repository.dart';
import 'synthetic_voice.dart';

/// Populates a fresh install with demo data. Credentials are listed in
/// CLAUDE.md. Seeded ids are fixed so an interrupted seed can safely re-run,
/// and each stage runs once, tracked by a version number in the meta box.
class DemoSeeder {
  DemoSeeder({
    required UserRepository users,
    required AuthRepository auth,
    required CompletionRepository completions,
    required ReminderRepository reminders,
    required RecordingRepository recordings,
    required RecordingFiles recordingFiles,
    required ParticipantRecordRepository participants,
    required QuestionnaireRepository questionnaires,
    required MonitoringRepository monitoring,
    required UsageLogRepository usage,
    required SeedStateRepository seedState,
  }) : _users = users,
       _auth = auth,
       _completions = completions,
       _reminders = reminders,
       _recordings = recordings,
       _recordingFiles = recordingFiles,
       _participants = participants,
       _questionnaires = questionnaires,
       _monitoring = monitoring,
       _usage = usage,
       _seedState = seedState;

  static const adminPassword = 'AdminDemo2026';
  static const therapistPassword = 'TherapistDemo2026';
  static const patientPassword = 'PatientDemo2026';

  final UserRepository _users;
  final AuthRepository _auth;
  final CompletionRepository _completions;
  final ReminderRepository _reminders;
  final RecordingRepository _recordings;
  final RecordingFiles _recordingFiles;
  final ParticipantRecordRepository _participants;
  final QuestionnaireRepository _questionnaires;
  final MonitoringRepository _monitoring;
  final UsageLogRepository _usage;
  final SeedStateRepository _seedState;

  Future<void> seedIfNeeded({DateTime? now}) async {
    final seeded = await _seedState.version();
    final today = dateOnly(now ?? DateTime.now());
    final enrolled = addDays(today, -15);

    if (seeded < 1) {
      await _seedAccounts(enrolled);
      await _seedState.setVersion(1);
    }
    if (seeded < 2) {
      await _seedReminders();
      await _seedState.setVersion(2);
    }
    if (seeded < 3) {
      await _seedRecordings(enrolled);
      await _seedState.setVersion(3);
    }
    if (seeded < 5) {
      await _seedStudy(today);
      await _seedState.setVersion(5);
    }
  }

  /// Stage 5: study records, questionnaires, monitoring forms and usage for
  /// the demo patients, plus P006, who has finished the intervention.
  /// Existing installs keep their own enrolment dates.
  Future<void> _seedStudy(DateTime today) async {
    await _seedCompletedParticipant(addDays(today, -completedStartOffset));

    final starts = <String, DateTime>{};
    for (var n = 1; n <= 6; n++) {
      final user = await _users.findById('patient-P00$n');
      if (user != null) starts[user.id] = dateOnly(user.createdAt);
    }
    for (final record in demoParticipantRecords(starts)) {
      await _participants.save(record);
    }
    for (final report in demoSelfReports(starts)) {
      await _questionnaires.saveSelfReport(report);
    }
    for (final entry in demoMonitoring(starts)) {
      await _monitoring.save(entry);
    }
    // The usage log is append-only, so a re-run after an interruption must
    // not add the history twice.
    if ((await _usage.all()).isEmpty) {
      final completions = [
        for (final MapEntry(key: id, value: start) in starts.entries)
          ...await _completions.forPatient(id, from: start, to: today),
      ];
      for (final event in demoUsage(completions, starts)) {
        await _usage.append(event);
      }
    }
  }

  Future<void> _seedCompletedParticipant(DateTime start) async {
    if (await _users.findById(completedPatientId) == null) {
      await _users.save(
        User(
          id: completedPatientId,
          role: UserRole.patient,
          name: completedPatientName,
          email: '${completedPatientCode.toLowerCase()}@melo.local',
          createdAt: start,
          participantCode: completedPatientCode,
          therapistId: completedPatientTherapist,
        ),
      );
      await _auth.setPassword(
        userId: completedPatientId,
        password: patientPassword,
      );
    }
    await _reminders.save(completedPatientId, const [
      ReminderTime(9, 0),
      ReminderTime(18, 30),
    ]);
    await _writeRecordings(completedPatientRecordings(), start);
  }

  Future<void> _seedRecordings(DateTime enrolled) =>
      _writeRecordings(demoRecordings(), enrolled);

  /// Writes synthetic voice files for [plans]. Ids are fixed per plan
  /// position, so re-running overwrites rather than duplicates.
  Future<void> _writeRecordings(
    List<DemoRecording> plans,
    DateTime enrolled,
  ) async {
    for (final (index, plan) in plans.indexed) {
      final createdAt = addDays(
        enrolled,
        plan.dayOffset,
      ).add(Duration(hours: 10, minutes: 5 * index));
      final path = await _recordingFiles.permanentPath(
        participantCode: plan.participantCode,
        type: plan.type,
        task: plan.task,
        createdAt: createdAt,
      );
      final bytes = await Isolate.run(
        () => syntheticVoiceWav(
          seconds: plan.seconds,
          pitchHz: plan.pitchHz,
          seed: index,
        ),
      );
      await _recordingFiles.writeEncrypted(bytes, path);
      await _recordings.save(
        Recording(
          id: 'rec-${plan.participantCode}-$index',
          patientId: 'patient-${plan.participantCode}',
          kind: plan.kind,
          task: plan.task,
          type: plan.type,
          filePath: path,
          durationSec: plan.seconds,
          createdAt: createdAt,
        ),
      );
    }
  }

  Future<void> _seedAccounts(DateTime enrolled) async {
    final accounts = _accounts(enrolled);
    for (final (user, _) in accounts) {
      await _users.save(user);
    }
    await Future.wait([
      for (final (user, password) in accounts)
        _auth.setPassword(userId: user.id, password: password),
    ]);
  }

  Future<void> _seedReminders() async {
    for (var n = 1; n <= 5; n++) {
      await _reminders.save('patient-P00$n', const [
        ReminderTime(9, 0),
        ReminderTime(18, 30),
      ]);
    }
  }

  List<(User, String)> _accounts(DateTime enrolled) {
    User staff(String id, UserRole role, String name, String email) => User(
      id: id,
      role: role,
      name: name,
      email: email,
      createdAt: enrolled.subtract(const Duration(days: 30)),
    );

    User patient(int n, String name, String therapistId) {
      final code = 'P${n.toString().padLeft(3, '0')}';
      return User(
        id: 'patient-$code',
        role: UserRole.patient,
        name: name,
        email: '${code.toLowerCase()}@melo.local',
        createdAt: enrolled,
        participantCode: code,
        therapistId: therapistId,
      );
    }

    const ortiz = 'therapist-01';
    const park = 'therapist-02';
    return [
      (
        staff('admin-01', UserRole.admin, 'Morgan Reyes', 'admin@melo.local'),
        adminPassword,
      ),
      (
        staff(ortiz, UserRole.therapist, 'Alina Ortiz', 'a.ortiz@melo.local'),
        therapistPassword,
      ),
      (
        staff(park, UserRole.therapist, 'Samuel Park', 's.park@melo.local'),
        therapistPassword,
      ),
      (patient(1, 'Grace Liu', ortiz), patientPassword),
      (patient(2, 'Daniel Okafor', ortiz), patientPassword),
      (patient(3, 'Priya Shah', ortiz), patientPassword),
      (patient(4, 'Tomas Lindqvist', park), patientPassword),
      (patient(5, 'Hannah Becker', park), patientPassword),
    ];
  }
}

final demoSeederProvider = Provider<DemoSeeder>(
  (ref) => DemoSeeder(
    users: ref.watch(userRepositoryProvider),
    auth: ref.watch(authRepositoryProvider),
    completions: ref.watch(completionRepositoryProvider),
    reminders: ref.watch(reminderRepositoryProvider),
    recordings: ref.watch(recordingRepositoryProvider),
    recordingFiles: ref.watch(recordingFilesProvider),
    participants: ref.watch(participantRecordRepositoryProvider),
    questionnaires: ref.watch(questionnaireRepositoryProvider),
    monitoring: ref.watch(monitoringRepositoryProvider),
    usage: ref.watch(usageLogRepositoryProvider),
    seedState: HiveSeedStateRepository(ref.watch(localDatabaseProvider).meta),
  ),
);
