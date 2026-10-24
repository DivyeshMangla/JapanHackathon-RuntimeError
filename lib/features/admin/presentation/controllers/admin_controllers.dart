import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/errors/app_failure.dart';
import '../../../../core/errors/guard.dart';
import '../../../../core/utils/dates.dart';
import '../../../audit/domain/access_log.dart';
import '../../../audit/presentation/controllers/access_log_controllers.dart';
import '../../../auth/data/auth_repository_providers.dart';
import '../../../auth/domain/user.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../recordings/data/recording_repository_providers.dart';
import '../../../therapist/domain/participant_summary.dart';
import '../../../therapist/presentation/controllers/caseload_controllers.dart';
import '../../../usage/data/usage_log_providers.dart';
import '../../data/csv_export.dart';
import '../../domain/study_overview.dart';

final usersByRoleProvider = FutureProvider.family<List<User>, UserRole>(
  (ref, role) => ref.watch(userRepositoryProvider).listByRole(role),
);

/// Every enrolled patient with their voice samples.
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
    voiceSamples: participants.fold(0, (sum, p) => sum + p.recordings.length),
  );
});

final adminActionsProvider = Provider<AdminActions>(AdminActions.new);

class AdminActions {
  AdminActions(this._ref);

  final Ref _ref;

  /// Creates an account. Patients get the next free participant code and
  /// must be assigned to a therapist.
  Future<User> createUser({
    required UserRole role,
    required String name,
    required String email,
    required String password,
    String? therapistId,
  }) async {
    if (role == UserRole.parent && therapistId == null) {
      throw const InvalidInputFailure(InputProblem.therapistRequired);
    }
    final user = await _ref
        .read(userRepositoryProvider)
        .create(
          role: role,
          name: name.trim(),
          email: email.trim().toLowerCase(),
          password: password,
          therapistId: role == UserRole.parent ? therapistId : null,
        );
    _ref.invalidate(usersByRoleProvider(role));
    return user;
  }

  Future<void> reassign(User patient, String therapistId) async {
    await _ref
        .read(userRepositoryProvider)
        .assignTherapist(patientId: patient.id, therapistId: therapistId);
    _ref
      ..invalidate(userByIdProvider(patient.id))
      ..invalidate(usersByRoleProvider(UserRole.patient));
  }
}

enum ExportKind {
  recordings('recording-metadata'),
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
    final csv = switch (kind) {
      ExportKind.recordings => CsvExport.recordings(
        recordings: await _ref.read(recordingRepositoryProvider).all(),
        codes: codes,
      ),
      ExportKind.usageLog => CsvExport.usageLog(
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
