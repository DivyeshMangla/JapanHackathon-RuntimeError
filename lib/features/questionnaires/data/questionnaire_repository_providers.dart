import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/local_database.dart';
import '../domain/questionnaire.dart';
import 'hive_questionnaire_repository.dart';

final questionnaireRepositoryProvider = Provider<QuestionnaireRepository>(
  (ref) => HiveQuestionnaireRepository(
    ref.watch(localDatabaseProvider).questionnaires,
  ),
);
