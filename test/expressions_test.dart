import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:melo/core/errors/app_failure.dart';
import 'package:melo/core/theme/app_theme.dart';
import 'package:melo/core/utils/l10n.dart';
import 'package:melo/features/auth/domain/user.dart';
import 'package:melo/features/auth/presentation/controllers/auth_controller.dart';
import 'package:melo/features/expressions/data/expression_providers.dart';
import 'package:melo/features/expressions/domain/expression.dart';
import 'package:melo/features/expressions/domain/expression_repository.dart';
import 'package:melo/features/expressions/presentation/child_expressions_screen.dart';
import 'package:melo/features/expressions/presentation/expression_face.dart';
import 'package:melo/features/expressions/presentation/expression_strings.dart';

final _child = User(
  id: 'child',
  role: UserRole.patient,
  name: 'Synthetic child',
  email: '',
  createdAt: DateTime(2026),
);

class _TestAuth extends AuthController {
  @override
  Future<User?> build() async => _child;
}

class _Repository implements ExpressionRepository {
  final assignment = ExpressionAssignment(
    id: 'assignment',
    feelings: [Feeling.happy, Feeling.sad],
    enabled: true,
  );
  bool failNextSend = true;
  final sentIds = <String>[];
  final sentAnswers = <List<ExpressionAnswer>>[];
  final sessions = <ExpressionSession>[];

  @override
  Future<ExpressionRecord> recordFor(String childId) async => ExpressionRecord(
    assignment: assignment,
    consented: true,
    sessions: sessions,
  );

  @override
  Future<ExpressionSession> submit({
    required String childId,
    required String assignmentId,
    required String sessionId,
    required List<ExpressionAnswer> answers,
    required ExpressionAssistance assistance,
  }) async {
    sentIds.add(sessionId);
    sentAnswers.add(List.of(answers));
    if (failNextSend) {
      failNextSend = false;
      throw const NetworkFailure(NetworkProblem.offline);
    }
    final session = ExpressionSession(
      id: sessionId,
      assignmentId: assignmentId,
      createdAt: DateTime(2026),
      correct: 2,
      total: 4,
      accuracy: 50,
      assistance: assistance,
      perExpression: const [],
      confusions: const [],
      items: const [],
    );
    sessions.add(session);
    return session;
  }

  @override
  Future<void> assign(
    String childId,
    List<Feeling> feelings, {
    required bool enabled,
  }) async {}
  @override
  Future<void> review(String sessionId, String note) async {}
}

Future<void> _pump(
  WidgetTester tester,
  _Repository repository, {
  double width = 390,
  double scale = 1,
}) async {
  tester.view.physicalSize = Size(width, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentUserProvider.overrideWithValue(_child),
        authControllerProvider.overrideWith(_TestAuth.new),
        expressionRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: const ChildExpressionsScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, String text) async {
  final finder = find.text(text);
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      finder,
      200,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'child round keeps answers until all pictures are answered and safely retries the same submission',
    (tester) async {
      final repository = _Repository();
      await _pump(tester, repository);
      await _tap(tester, ExpressionStrings.start);
      for (var question = 1; question <= 4; question++) {
        expect(
          find.text(ExpressionStrings.question(question, 4)),
          findsOneWidget,
        );
        final face = tester.widget<ExpressionFace>(find.byType(ExpressionFace));
        expect(face.semanticLabel, ExpressionStrings.pictureLabel(question));
        expect(find.textContaining('Picture label:'), findsNothing);
        expect(repository.sentIds, isEmpty);
        await _tap(tester, ExpressionStrings.label(Feeling.happy));
        await _tap(tester, ExpressionStrings.next);
      }
      expect(find.text(ExpressionStrings.finish), findsOneWidget);
      await _tap(tester, ExpressionStrings.send);
      expect(find.text(ExpressionStrings.retry), findsOneWidget);
      await _tap(tester, ExpressionStrings.retry);
      expect(find.text(ExpressionStrings.sent), findsOneWidget);
      expect(repository.sentIds, hasLength(2));
      expect(repository.sentIds[0], repository.sentIds[1]);
      expect(
        repository.sentAnswers[0].map((answer) => answer.pictureId).toSet(),
        {'happy-1', 'happy-2', 'sad-1', 'sad-2'},
      );
      expect(
        repository.sentAnswers[0].map(
          (answer) => '${answer.pictureId}:${answer.selected.name}',
        ),
        repository.sentAnswers[1].map(
          (answer) => '${answer.pictureId}:${answer.selected.name}',
        ),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'feelings activity and quiz fit a narrow phone with enlarged text',
    (tester) async {
      await _pump(tester, _Repository(), width: 320, scale: 2);
      expect(tester.takeException(), isNull);
      await _tap(tester, ExpressionStrings.start);
      expect(tester.takeException(), isNull);
    },
  );
}
