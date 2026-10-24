import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../study/presentation/controllers/study_controllers.dart';
import '../../../usage/domain/usage_event.dart';
import '../../../usage/presentation/controllers/usage_controllers.dart';
import '../../data/questionnaire_repository_providers.dart';
import '../../domain/questionnaire.dart';
import '../../domain/study_tasks.dart';

final questionnaireHistoryProvider =
    FutureProvider.family<QuestionnaireHistory, String>(
      (ref, patientId) =>
          ref.watch(questionnaireRepositoryProvider).forPatient(patientId),
    );

/// Questionnaires the participant should fill in today.
final studyTasksProvider = FutureProvider.family<List<StudyTask>, String>((
  ref,
  patientId,
) async {
  final period = await ref.watch(studyPeriodProvider(patientId).future);
  final record = await ref.watch(participantRecordProvider(patientId).future);
  final history = await ref.watch(
    questionnaireHistoryProvider(patientId).future,
  );
  return StudyTasks.due(
    period: period,
    history: history,
    today: DateTime.now(),
    withdrawn: record.isWithdrawn,
  );
});

final questionnaireActionsProvider = Provider<QuestionnaireActions>(
  QuestionnaireActions.new,
);

class QuestionnaireActions {
  QuestionnaireActions(this._ref);

  final Ref _ref;

  Future<void> submitSelfReport({
    required String patientId,
    required int week,
    required int daysPractised,
    required PracticeBarrier barrier,
    required String note,
  }) => _submit(
    patientId,
    'self-report-week-$week',
    (repository) => repository.saveSelfReport(
      AdherenceSelfReport(
        id: const Uuid().v4(),
        patientId: patientId,
        week: week,
        submittedAt: DateTime.now(),
        daysPractised: daysPractised,
        barrier: barrier,
        note: note.trim(),
      ),
    ),
  );

  Future<void> submitUsability({
    required String patientId,
    required List<int> answers,
  }) => _submit(
    patientId,
    'usability',
    (repository) => repository.saveUsability(
      UsabilityResponse(
        id: const Uuid().v4(),
        patientId: patientId,
        submittedAt: DateTime.now(),
        answers: answers,
      ),
    ),
  );

  Future<void> submitFeedback({
    required String patientId,
    required Map<SatisfactionItem, int> ratings,
    required String likedMost,
    required String difficulties,
    required String suggestions,
  }) => _submit(
    patientId,
    'feedback',
    (repository) => repository.saveSatisfaction(
      SatisfactionResponse(
        id: const Uuid().v4(),
        patientId: patientId,
        submittedAt: DateTime.now(),
        ratings: ratings,
        likedMost: likedMost.trim(),
        difficulties: difficulties.trim(),
        suggestions: suggestions.trim(),
      ),
    ),
  );

  Future<void> _submit(
    String patientId,
    String usageDetail,
    Future<void> Function(QuestionnaireRepository repository) write,
  ) async {
    await write(_ref.read(questionnaireRepositoryProvider));
    _ref.invalidate(questionnaireHistoryProvider(patientId));
    await _ref
        .read(usageLoggerProvider)
        .record(UsageAction.questionnaireSubmitted, detail: usageDetail);
  }
}
