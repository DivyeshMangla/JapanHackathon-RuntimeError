import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/errors/app_failure.dart';
import '../../../../core/errors/guard.dart';
import '../../../../core/utils/dates.dart';
import '../../../audit/domain/access_log.dart';
import '../../../audit/presentation/controllers/access_log_controllers.dart';
import '../../../auth/data/auth_repository_providers.dart';
import '../../../auth/domain/user.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../exercises/data/exercise_repository_providers.dart';
import '../../../exercises/domain/adherence.dart';
import '../../../exercises/domain/exercise.dart';
import '../../../exercises/presentation/controllers/exercise_controllers.dart';
import '../../../questionnaires/data/questionnaire_repository_providers.dart';
import '../../../questionnaires/presentation/controllers/questionnaire_controllers.dart';
import '../../../recordings/data/recording_repository_providers.dart';
import '../../../settings/presentation/controllers/study_settings_controller.dart';
import '../../../study/data/study_repository_providers.dart';
import '../../../study/domain/participant_record.dart';
import '../../../study/domain/participant_status.dart';
import '../../../study/domain/study_outcomes.dart';
import '../../../study/presentation/controllers/study_controllers.dart';
import '../../../therapist/domain/participant_summary.dart';
import '../../../therapist/presentation/controllers/caseload_controllers.dart';
import '../../../usage/data/usage_log_providers.dart';
import '../../data/csv_export.dart';
import '../../data/study_csv_export.dart';
import '../../domain/study_overview.dart';

final usersByRoleProvider = FutureProvider.family<List<User>, UserRole>(
  (ref, role) => ref.watch(userRepositoryProvider).listByRole(role),
);

/// Every enrolled patient with activity and status, by participant code.
final studyParticipantsProvider = FutureProvider<List<ParticipantSummary>>((
  ref,
) async {
  final patients = await ref.watch(
    usersByRoleProvider(UserRole.patient).future,
  );
  return Future.wait([
    for (final p in patients)
      ref.watch(participantSummaryProvider(p.id).future),
  ]);
});

final studyOverviewProvider = FutureProvider<StudyOverview>((ref) async {
  final participants = await ref.watch(studyParticipantsProvider.future);
  final therapists = await ref.watch(
    usersByRoleProvider(UserRole.therapist).future,
  );
  return StudyOverview(
    enrolled: participants.length,
    therapists: therapists.length,
    overallAdherence: Adherence.rate([
      for (final p in participants) ...p.activity.recent,
    ]),
    lowAdherence: participants.where((p) => p.lowAdherence).length,
    statusCounts: {
      for (final status in ParticipantStatus.values)
        status: participants.where((p) => p.status == status).length,
    },
  );
});

/// Outcome inputs for every enrolled participant, by participant code.
final participantOutcomesProvider = FutureProvider<List<ParticipantOutcome>>((
  ref,
) async {
  final patients = await ref.watch(
    usersByRoleProvider(UserRole.patient).future,
  );
  return Future.wait([for (final p in patients) _outcomeOf(ref, p)]);
});

Future<ParticipantOutcome> _outcomeOf(Ref ref, User patient) async =>
    ParticipantOutcome(
      patientId: patient.id,
      code: patient.participantCode ?? patient.id,
      record: await ref.watch(participantRecordProvider(patient.id).future),
      outcome: await ref.watch(interventionOutcomeProvider(patient.id).future),
      questionnaires: await ref.watch(
        questionnaireHistoryProvider(patient.id).future,
      ),
    );

/// The protocol's outcome measures across the study.
final studyOutcomesProvider = FutureProvider<StudyOutcomes>((ref) async {
  final participants = await ref.watch(participantOutcomesProvider.future);
  final settings = await ref.watch(studySettingsProvider.future);
  return StudyOutcomes.compute(
    participants: participants,
    approached: settings.participantsApproached,
    adherenceThreshold: settings.adherenceThreshold,
    today: DateTime.now(),
  );
});

final adminActionsProvider = Provider<AdminActions>(AdminActions.new);

class AdminActions {
  AdminActions(this._ref);

  final Ref _ref;

  /// Creates an account. Patients get the next free participant code, must
  /// be assigned to a therapist, and must have documented consent; their
  /// study record starts with the intervention beginning today.
  Future<User> createUser({
    required UserRole role,
    required String name,
    required String email,
    required String password,
    String? therapistId,
    bool infoSheetProvided = false,
    DateTime? consentSignedOn,
  }) async {
    final users = _ref.read(userRepositoryProvider);
    final normalized = email.trim().toLowerCase();
    if (await users.findByEmail(normalized) != null) {
      throw const InvalidInputFailure(InputProblem.emailTaken);
    }
    if (role == UserRole.patient && therapistId == null) {
      throw const InvalidInputFailure(InputProblem.therapistRequired);
    }
    if (role == UserRole.patient &&
        (!infoSheetProvided || consentSignedOn == null)) {
      throw const InvalidInputFailure(InputProblem.consentRequired);
    }
    final user = User(
      id: const Uuid().v4(),
      role: role,
      name: name.trim(),
      email: normalized,
      createdAt: DateTime.now(),
      participantCode: role == UserRole.patient
          ? await _nextParticipantCode()
          : null,
      therapistId: role == UserRole.patient ? therapistId : null,
    );
    await users.save(user);
    await _ref
        .read(authRepositoryProvider)
        .setPassword(userId: user.id, password: password);
    if (role == UserRole.patient) {
      await _ref
          .read(participantRecordRepositoryProvider)
          .save(
            ParticipantRecord(
              patientId: user.id,
              interventionStart: dateOnly(user.createdAt),
              infoSheetProvided: infoSheetProvided,
              consentSignedOn: consentSignedOn,
            ),
          );
    }
    _ref.invalidate(usersByRoleProvider(role));
    return user;
  }

  Future<void> reassign(User patient, String therapistId) async {
    await _ref
        .read(userRepositoryProvider)
        .save(patient.copyWith(therapistId: therapistId));
    _ref
      ..invalidate(userByIdProvider(patient.id))
      ..invalidate(usersByRoleProvider(UserRole.patient));
  }

  Future<String> _nextParticipantCode() async {
    final patients = await _ref
        .read(userRepositoryProvider)
        .listByRole(UserRole.patient);
    var highest = 0;
    for (final p in patients) {
      final n = int.tryParse((p.participantCode ?? '').replaceAll('P', ''));
      if (n != null && n > highest) highest = n;
    }
    return 'P${(highest + 1).toString().padLeft(3, '0')}';
  }
}

final libraryActionsProvider = Provider<LibraryActions>(LibraryActions.new);

/// Exercise library management. Any content change needs approval again.
class LibraryActions {
  LibraryActions(this._ref);

  final Ref _ref;

  Future<void> save(Exercise exercise) async {
    await _ref.read(exerciseRepositoryProvider).save(exercise);
    _ref.invalidate(exerciseLibraryProvider);
  }

  Future<void> approve(Exercise exercise) => save(
    exercise.approve(by: _ref.read(currentUserProvider).id, at: DateTime.now()),
  );

  Future<void> setArchived(Exercise exercise, bool archived) =>
      save(exercise.withArchived(archived));
}

enum ExportKind {
  participants('participants'),
  outcomes('outcomes'),
  completions('completions'),
  assignments('assignments'),
  recordings('recording-metadata'),
  selfReports('self-reports'),
  monitoring('monitoring-forms'),
  usability('usability'),
  feedback('feedback'),
  voiceDiary('voice-use-diary'),
  usageLog('usage-log');

  const ExportKind(this.slug);

  final String slug;
}

final exportActionsProvider = Provider<ExportActions>(ExportActions.new);

class ExportActions {
  ExportActions(this._ref);

  final Ref _ref;

  /// Builds the CSV and asks the user where to save it. Returns the file
  /// name when saved, or null if they cancelled. Saved exports are logged.
  Future<String?> export(
    ExportKind kind, {
    required String Function(String fileName) saveDialogTitle,
  }) => guard(
    () => _export(kind, saveDialogTitle: saveDialogTitle),
    ExportFailure.new,
  );

  Future<String?> _export(
    ExportKind kind, {
    required String Function(String fileName) saveDialogTitle,
  }) async {
    final patients = await _ref
        .read(userRepositoryProvider)
        .listByRole(UserRole.patient);
    final codes = CsvExport.participantCodes(patients);
    final library = {
      for (final e in await _ref.read(exerciseRepositoryProvider).all())
        e.id: e,
    };
    final csv = switch (kind) {
      ExportKind.completions => CsvExport.completions(
        completions: await _ref.read(completionRepositoryProvider).all(),
        codes: codes,
        exercises: library,
      ),
      ExportKind.assignments => CsvExport.assignments(
        schedules: await _ref.read(scheduleRepositoryProvider).all(),
        codes: codes,
        exercises: library,
      ),
      ExportKind.recordings => CsvExport.recordings(
        recordings: await _ref.read(recordingRepositoryProvider).all(),
        codes: codes,
      ),
      ExportKind.participants => StudyCsvExport.participants(
        records: await _ref.read(participantRecordRepositoryProvider).all(),
        patients: patients,
      ),
      ExportKind.outcomes => StudyCsvExport.outcomes(
        participants: await _ref.read(participantOutcomesProvider.future),
        threshold: (await _ref.read(
          studySettingsProvider.future,
        )).adherenceThreshold,
      ),
      ExportKind.selfReports => StudyCsvExport.selfReports(
        reports: await _ref
            .read(questionnaireRepositoryProvider)
            .allSelfReports(),
        codes: codes,
      ),
      ExportKind.monitoring => StudyCsvExport.monitoring(
        entries: await _ref.read(monitoringRepositoryProvider).all(),
        codes: codes,
      ),
      ExportKind.usability => StudyCsvExport.usability(
        responses: await _ref
            .read(questionnaireRepositoryProvider)
            .allUsability(),
        codes: codes,
      ),
      ExportKind.feedback => StudyCsvExport.feedback(
        responses: await _ref
            .read(questionnaireRepositoryProvider)
            .allSatisfaction(),
        codes: codes,
      ),
      ExportKind.voiceDiary => StudyCsvExport.voiceDiary(
        entries: await _ref.read(voiceDiaryRepositoryProvider).all(),
        codes: codes,
      ),
      ExportKind.usageLog => StudyCsvExport.usageLog(
        events: await _ref.read(usageLogRepositoryProvider).all(),
        codes: codes,
      ),
    };

    final stamp = DateFormat('yyyyMMdd').format(dateOnly(DateTime.now()));
    final fileName = 'melo-${kind.slug}-$stamp.csv';
    final saved = await FilePicker.saveFile(
      fileName: fileName,
      bytes: Uint8List.fromList(utf8.encode(csv)),
      mimeType: 'text/csv',
      dialogTitle: saveDialogTitle(fileName),
    );
    if (saved == null) return null;

    await _ref.read(accessLoggerProvider).record(AccessAction.export, fileName);
    return fileName;
  }
}
