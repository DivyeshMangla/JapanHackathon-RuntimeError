import 'expression.dart';

abstract interface class ExpressionRepository {
  Future<ExpressionRecord> recordFor(String childId);
  Future<void> assign(
    String childId,
    List<Feeling> feelings, {
    required bool enabled,
  });
  Future<ExpressionSession> submit({
    required String childId,
    required String assignmentId,
    required String sessionId,
    required List<ExpressionAnswer> answers,
    required ExpressionAssistance assistance,
  });
  Future<void> review(String sessionId, String note);
}
