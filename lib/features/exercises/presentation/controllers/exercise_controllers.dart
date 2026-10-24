import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/errors/app_failure.dart';
import '../../../../core/utils/dates.dart';
import '../../../study/presentation/controllers/study_controllers.dart';
import '../../../usage/domain/usage_event.dart';
import '../../../usage/presentation/controllers/usage_controllers.dart';
import '../../data/exercise_repository_providers.dart';
import '../../domain/adherence.dart';
import '../../domain/completion.dart';
import '../../domain/exercise.dart';
import '../../domain/patient_activity.dart';
import '../../domain/schedule.dart';
import '../../domain/voice_use_entry.dart';

final exerciseLibraryProvider = FutureProvider<List<Exercise>>(
  (ref) => ref.watch(exerciseRepositoryProvider).all(),
);

final patientActivityProvider = FutureProvider.family<PatientActivity, String>((
  ref,
  patientId,
) async {
  final today = dateOnly(DateTime.now());
  final from = addDays(today, 1 - historyDays);

  final schedules = await ref
      .watch(scheduleRepositoryProvider)
      .forPatient(patientId);
  final library = await ref.watch(exerciseLibraryProvider.future);
  final completions = await ref
      .watch(completionRepositoryProvider)
      .forPatient(patientId, from: from, to: today);

  return PatientActivity(
    today: today,
    schedules: schedules,
    exercises: {for (final e in library) e.id: e},
    completions: completions,
    days: Adherence.daily(
      schedules: schedules,
      completions: completions,
      from: from,
      to: today,
    ),
  );
});

/// A patient's voice-use diary, oldest first.
final voiceDiaryProvider = FutureProvider.family<List<VoiceUseEntry>, String>(
  (ref, patientId) =>
      ref.watch(voiceDiaryRepositoryProvider).forPatient(patientId),
);

final completionActionsProvider = Provider<CompletionActions>(
  CompletionActions.new,
);

class CompletionActions {
  CompletionActions(this._ref);

  final Ref _ref;

  /// Records one more session of [item] today.
  Future<void> addSession(String patientId, DayItem item) async {
    if (item.isDone) return;
    final now = DateTime.now();
    await _ref
        .read(completionRepositoryProvider)
        .add(
          Completion(
            id: const Uuid().v4(),
            patientId: patientId,
            exerciseId: item.exercise.id,
            day: dateOnly(now),
            completedAt: now,
          ),
        );
    _invalidate(patientId);
    await _ref
        .read(usageLoggerProvider)
        .record(UsageAction.sessionMarked, detail: item.exercise.id);
  }

  /// Records a voice-use diary entry as one session of [item], which must
  /// be a voice-diary exercise.
  Future<void> logVoiceUse(
    String patientId,
    DayItem item, {
    required SpeakingTime speakingTime,
    required int fatigue,
    required Set<VoiceSituation> situations,
    required String note,
  }) async {
    if (item.isDone) return;
    final now = DateTime.now();
    await _ref
        .read(voiceDiaryRepositoryProvider)
        .save(
          VoiceUseEntry(
            id: const Uuid().v4(),
            patientId: patientId,
            day: dateOnly(now),
            loggedAt: now,
            speakingTime: speakingTime,
            fatigue: fatigue,
            situations: situations,
            note: note.trim(),
          ),
        );
    _ref.invalidate(voiceDiaryProvider(patientId));
    await addSession(patientId, item);
  }

  /// Undoes the most recent session of [item] today. For a voice-diary
  /// exercise the entry that made the session is removed with it, so the
  /// diary never holds more entries than sessions.
  Future<void> removeSession(String patientId, DayItem item) async {
    if (item.completions.isEmpty) return;
    if (item.exercise.verificationType == VerificationType.voiceDiary) {
      await _removeLatestDiaryEntry(patientId);
    }
    await _ref
        .read(completionRepositoryProvider)
        .delete(item.completions.last.id);
    _invalidate(patientId);
    await _ref
        .read(usageLoggerProvider)
        .record(UsageAction.sessionUndone, detail: item.exercise.id);
  }

  Future<void> _removeLatestDiaryEntry(String patientId) async {
    final repository = _ref.read(voiceDiaryRepositoryProvider);
    final today = dateOnly(DateTime.now());
    final latest = (await repository.forPatient(
      patientId,
    )).where((e) => e.day == today).lastOrNull;
    if (latest == null) return;
    await repository.delete(latest.id);
    _ref.invalidate(voiceDiaryProvider(patientId));
  }

  void _invalidate(String patientId) => _ref
    ..invalidate(patientActivityProvider(patientId))
    ..invalidate(interventionOutcomeProvider(patientId));
}

final scheduleActionsProvider = Provider<ScheduleActions>(ScheduleActions.new);

/// Therapist changes to a patient's assignments. Edits are versioned so past
/// adherence is never rescored.
class ScheduleActions {
  ScheduleActions(this._ref);

  final Ref _ref;

  Future<void> assign({
    required String patientId,
    required Exercise exercise,
    required Dosage dosage,
    required String therapistId,
  }) async {
    if (!exercise.isAssignable) {
      throw const InvalidInputFailure(InputProblem.exerciseNotApproved);
    }
    if (exercise.needsInstructions && dosage.instructions.trim().isEmpty) {
      throw const InvalidInputFailure(InputProblem.instructionsRequired);
    }
    await _ref
        .read(scheduleRepositoryProvider)
        .save(
          Schedule(
            id: const Uuid().v4(),
            patientId: patientId,
            exerciseId: exercise.id,
            weekdays: dosage.weekdays,
            sessionsPerDay: dosage.sessionsPerDay,
            repetitions: dosage.repetitions,
            targets: dosage.targets,
            instructions: dosage.instructions,
            effectiveFrom: dateOnly(DateTime.now()),
            assignedBy: therapistId,
          ),
        );
    _ref
      ..invalidate(patientActivityProvider(patientId))
      ..invalidate(interventionOutcomeProvider(patientId));
  }

  Future<void> revise(
    Schedule current,
    Dosage dosage, {
    required String therapistId,
  }) => _apply(
    current.patientId,
    ScheduleVersioning.revise(
      current: current,
      revised: current.copyWith(
        weekdays: dosage.weekdays,
        sessionsPerDay: dosage.sessionsPerDay,
        repetitions: dosage.repetitions,
        targets: dosage.targets,
        instructions: dosage.instructions,
        assignedBy: therapistId,
      ),
      today: DateTime.now(),
      newId: const Uuid().v4(),
    ),
  );

  Future<void> end(Schedule current) => _apply(
    current.patientId,
    ScheduleVersioning.end(current: current, today: DateTime.now()),
  );

  Future<void> _apply(String patientId, ScheduleChange change) async {
    final repository = _ref.read(scheduleRepositoryProvider);
    for (final schedule in change.save) {
      await repository.save(schedule);
    }
    for (final id in change.delete) {
      await repository.delete(id);
    }
    _ref
      ..invalidate(patientActivityProvider(patientId))
      ..invalidate(interventionOutcomeProvider(patientId));
  }
}
