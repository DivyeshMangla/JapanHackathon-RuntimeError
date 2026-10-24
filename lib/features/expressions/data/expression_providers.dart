import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/backend_client.dart';
import '../../auth/presentation/controllers/auth_controller.dart';
import '../domain/expression.dart';
import '../domain/expression_repository.dart';
import 'backend_expression_repository.dart';

final expressionRepositoryProvider = Provider<ExpressionRepository>(
  (ref) => BackendExpressionRepository(ref.watch(backendClientProvider)),
);
final expressionRecordProvider = FutureProvider.autoDispose
    .family<ExpressionRecord, String>((ref, childId) {
      ref.watch(authControllerProvider.select((session) => session.value?.id));
      return ref.watch(expressionRepositoryProvider).recordFor(childId);
    });
