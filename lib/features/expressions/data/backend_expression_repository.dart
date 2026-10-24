import '../../../core/errors/app_failure.dart';
import '../../../core/errors/guard.dart';
import '../../../core/network/backend_client.dart';
import '../domain/expression.dart';
import '../domain/expression_repository.dart';

class BackendExpressionRepository implements ExpressionRepository {
  const BackendExpressionRepository(this._client);
  final BackendClient _client;

  @override
  Future<ExpressionRecord> recordFor(String childId) => guard(() async {
    final response = await _client.get('/patients/$childId/expressions');
    final assignment = response['assignment'];
    return ExpressionRecord(
      assignment: assignment is JsonObject
          ? ExpressionAssignment(
              id: assignment['id']! as String,
              feelings: [
                for (final value
                    in assignment['expressionIds']! as List<Object?>)
                  Feeling.values.byName(value! as String),
              ],
              enabled: assignment['enabled']! as bool,
            )
          : null,
      consented: response['consented']! as bool,
      sessions: response.objects('sessions').map(_session).toList(),
    );
  }, (_) => const NetworkFailure(NetworkProblem.badResponse));

  @override
  Future<void> assign(
    String childId,
    List<Feeling> feelings, {
    required bool enabled,
  }) async {
    await _client.put(
      '/patients/$childId/expressions',
      body: {
        'expressionIds': feelings.map((value) => value.name).toList(),
        'enabled': enabled,
      },
    );
  }

  @override
  Future<ExpressionSession> submit({
    required String childId,
    required String assignmentId,
    required String sessionId,
    required List<ExpressionAnswer> answers,
    required ExpressionAssistance assistance,
  }) => guard(() async {
    final response = await _client.post(
      '/patients/$childId/expression-sessions',
      body: {
        'id': sessionId,
        'assignmentId': assignmentId,
        'assistance': assistance == ExpressionAssistance.independent
            ? 'independent'
            : 'with_help',
        'answers': [
          for (final answer in answers)
            {'pictureId': answer.pictureId, 'selected': answer.selected.name},
        ],
      },
    );
    return _session(response.object('session'));
  }, (_) => const NetworkFailure(NetworkProblem.badResponse));

  @override
  Future<void> review(String sessionId, String note) async {
    await _client.post(
      '/expression-sessions/$sessionId/review',
      body: {'note': note},
    );
  }

  ExpressionSession _session(JsonObject value) => ExpressionSession(
    id: value['id']! as String,
    assignmentId: value['assignmentId']! as String,
    createdAt: DateTime.parse(value['createdAt']! as String).toLocal(),
    correct: value['correct']! as int,
    total: value['total']! as int,
    accuracy: (value['accuracy']! as num).toDouble(),
    assistance: value['assistance'] == 'with_help'
        ? ExpressionAssistance.withHelp
        : ExpressionAssistance.independent,
    perExpression: [
      for (final count in value.objects('perExpression'))
        FeelingCount(
          feeling: Feeling.values.byName(count['expressionId']! as String),
          correct: count['correct']! as int,
          total: count['total']! as int,
        ),
    ],
    confusions: [
      for (final confusion in value.objects('confusions'))
        ExpressionConfusion(
          expected: Feeling.values.byName(confusion['expected']! as String),
          selected: Feeling.values.byName(confusion['selected']! as String),
          count: confusion['count']! as int,
        ),
    ],
    items: [
      for (final item in value.objects('items'))
        ExpressionItem(
          pictureId: item['pictureId']! as String,
          expected: Feeling.values.byName(item['expected']! as String),
          selected: Feeling.values.byName(item['selected']! as String),
          correct: item['correct']! as bool,
        ),
    ],
    reviewNote: value['reviewNote'] as String?,
    reviewedBy: value['reviewedBy'] as String?,
    reviewedAt: value['reviewedAt'] is String
        ? DateTime.parse(value['reviewedAt']! as String).toLocal()
        : null,
  );
}
