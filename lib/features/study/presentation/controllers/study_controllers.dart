import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/utils/dates.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../exercises/data/exercise_repository_providers.dart';
import '../../../settings/presentation/controllers/study_settings_controller.dart';
import '../../data/study_repository_providers.dart';
import '../../domain/intervention_outcome.dart';
import '../../domain/monitoring_entry.dart';
import '../../domain/participant_record.dart';
import '../../domain/study_period.dart';

/// A patient's study record. Patients enrolled before records existed get an
/// undocumented record starting on their account's creation date.
final participantRecordProvider =
    FutureProvider.family<ParticipantRecord, String>((ref, patientId) async {
      final stored = await ref
          .watch(participantRecordRepositoryProvider)
          .forPatient(patientId);
      if (stored != null) return stored;
      final patient = await ref.watch(userByIdProvider(patientId).future);
      return ParticipantRecord.undocumented(
        patientId: patientId,
        enrolledOn: patient?.createdAt ?? DateTime.now(),
      );
    });

final studyPeriodProvider = FutureProvider.family<StudyPeriod, String>((
  ref,
  patientId,
) async {
  final record = await ref.watch(participantRecordProvider(patientId).future);
  final settings = await ref.watch(studySettingsProvider.future);
  return StudyPeriod(
    start: record.interventionStart,
    weeks: settings.studyWeeks,
  );
});

/// Adherence and compliance over the intervention, from the app log.
final interventionOutcomeProvider =
    FutureProvider.family<InterventionOutcome, String>((ref, patientId) async {
      final period = await ref.watch(studyPeriodProvider(patientId).future);
      final today = dateOnly(DateTime.now());
      final schedules = await ref
          .watch(scheduleRepositoryProvider)
          .forPatient(patientId);
      final completions = await ref
          .watch(completionRepositoryProvider)
          .forPatient(
            patientId,
            from: period.start,
            to: today.isAfter(period.end) ? period.end : today,
          );
      return InterventionOutcome.compute(
        period: period,
        schedules: schedules,
        completions: completions,
        today: today,
      );
    });

final monitoringEntriesProvider =
    FutureProvider.family<List<MonitoringEntry>, String>(
      (ref, patientId) =>
          ref.watch(monitoringRepositoryProvider).forPatient(patientId),
    );

final studyRecordActionsProvider = Provider<StudyRecordActions>(
  StudyRecordActions.new,
);

/// Writes to a participant's study record and monitoring forms.
class StudyRecordActions {
  StudyRecordActions(this._ref);

  final Ref _ref;

  Future<void> save(ParticipantRecord record) async {
    await _ref.read(participantRecordRepositoryProvider).save(record);
    _ref.invalidate(participantRecordProvider(record.patientId));
  }

  Future<void> withdraw(ParticipantRecord record, String reason) =>
      save(record.withdraw(on: DateTime.now(), reason: reason.trim()));

  Future<void> addMonitoring({
    required String patientId,
    required int week,
    required MonitoringRating practice,
    required MonitoringRating schedule,
    required MonitoringRating technique,
    required String barriers,
    required String notes,
  }) async {
    await _ref
        .read(monitoringRepositoryProvider)
        .save(
          MonitoringEntry(
            id: const Uuid().v4(),
            patientId: patientId,
            therapistId: _ref.read(currentUserProvider).id,
            week: week,
            recordedAt: DateTime.now(),
            practice: practice,
            schedule: schedule,
            technique: technique,
            barriers: barriers.trim(),
            notes: notes.trim(),
          ),
        );
    _ref.invalidate(monitoringEntriesProvider(patientId));
  }
}
