import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:melo/core/errors/app_failure.dart';
import 'package:melo/core/theme/app_theme.dart';
import 'package:melo/core/utils/l10n.dart';
import 'package:melo/features/progress/domain/family_progress.dart';
import 'package:melo/features/progress/presentation/controllers/progress_controllers.dart';
import 'package:melo/features/progress/presentation/progress_panel.dart';
import 'package:melo/features/progress/presentation/progress_strings.dart';

void main() {
  final practice = FamilyProgress(
    patientId: 'child',
    activities: const [
      ActivityProgress(
        activity: ProgressActivity.words,
        attempts: 5,
        reviewed: 2,
        clinicianCorrect: 1,
        clinicianNeedsPractice: 1,
      ),
      ActivityProgress(
        activity: ProgressActivity.expressions,
        attempts: 2,
        reviewed: 1,
        clinicianCorrect: 0,
        clinicianNeedsPractice: 0,
        quizCorrect: 7,
        quizTotal: 8,
        quizIndependentCorrect: 3,
        quizIndependentTotal: 4,
        quizAssistedCorrect: 4,
        quizAssistedTotal: 4,
      ),
    ],
    feedback: [
      TherapistFeedback(
        id: 'words-1',
        activity: ProgressActivity.words,
        title: 'help',
        text: 'Practise the first sound slowly together.',
        assessment: ClinicianAssessment.needsPractice,
        practiceAt: DateTime(2026, 10, 24),
        reviewedAt: DateTime(2026, 10, 25),
        therapistName: 'Dr Meera',
      ),
    ],
  );

  Widget page(Widget child) => MaterialApp(
    theme: AppTheme.light,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );

  testWidgets(
    'family dashboard separates participation, clinician assessments and assisted quiz results',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            familyProgressProvider(
              'child',
            ).overrideWith((ref) async => practice),
          ],
          child: page(const ProgressPanel(childId: 'child')),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('5 submitted · 2 reviewed · 3 awaiting review'),
        findsOneWidget,
      );
      expect(
        find.text('Therapist assessment: 1 correct · 1 to practise'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Without help: 3 of 4 correct'),
        findsOneWidget,
      );
      expect(
        find.textContaining('With adult help: 4 of 4 correct'),
        findsOneWidget,
      );
      expect(
        find.text('Practise the first sound slowly together.'),
        findsOneWidget,
      );
      expect(find.textContaining('Dr Meera · reviewed'), findsOneWidget);
      expect(
        find.text('40%'),
        findsNothing,
        reason: 'review completion must not become a clinical accuracy score',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'child guidance appears before participation and empty history explains next steps',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            familyProgressProvider(
              'child',
            ).overrideWith((ref) async => practice),
          ],
          child: page(
            const ProgressPanel(childId: 'child', childFriendly: true),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(find.text(ProgressStrings.feedback)).dy,
        lessThan(
          tester.getTopLeft(find.text(ProgressStrings.participation)).dy,
        ),
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            familyProgressProvider('child').overrideWith(
              (ref) async => FamilyProgress(
                patientId: 'child',
                activities: const [],
                feedback: const [],
              ),
            ),
          ],
          child: page(const ProgressPanel(childId: 'child')),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(ProgressStrings.noPracticeTitle), findsOneWidget);
      expect(find.text(ProgressStrings.noFeedbackTitle), findsOneWidget);
      expect(find.textContaining('%'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('failed loading offers a retry that fetches fresh guidance', (
    tester,
  ) async {
    var loads = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          familyProgressProvider('child').overrideWith((ref) async {
            loads++;
            if (loads == 1) throw const NetworkFailure(NetworkProblem.offline);
            return practice;
          }),
        ],
        child: page(const ProgressPanel(childId: 'child')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(ProgressStrings.retry), findsOneWidget);
    await tester.tap(find.text(ProgressStrings.retry));
    await tester.pumpAndSettle();
    expect(loads, 2);
    expect(
      find.text('Practise the first sound slowly together.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
