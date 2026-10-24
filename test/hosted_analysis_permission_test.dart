import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:melo/core/theme/app_theme.dart';
import 'package:melo/core/utils/l10n.dart';
import 'package:melo/features/parent/domain/hosted_analysis.dart';
import 'package:melo/features/parent/presentation/controllers/hosted_analysis_controllers.dart';
import 'package:melo/features/parent/presentation/parent_hosted_analysis_panel.dart';

HostedAnalysisPermission _permission({
  bool allowed = false,
  bool careConsentApproved = true,
}) => HostedAnalysisPermission(
  provider: 'groq',
  allowed: allowed,
  careConsentApproved: careConsentApproved,
  localAnalysisAllowed: false,
  disclosureVersion: 'test-disclosure-v1',
  disclosureText:
      'Optional online analysis sends the child’s practice photo or voice '
      'and therapist reference audio to Groq in the United States. '
      'Results may be wrong and need therapist review. '
      'Data may be retained for up to 30 days. '
      'Turning this off stops future requests. '
      'Practice and therapist feedback remain available either way. '
      'This is a separate optional permission and preserves signed care consent.',
  privacyUrl: 'https://console.groq.com/docs/your-data',
);

class _Repository implements HostedAnalysisRepository {
  _Repository(this.permission);

  HostedAnalysisPermission permission;
  final calls =
      <({String childId, bool allowed, String version, bool adult})>[];

  @override
  Future<HostedAnalysisPermission> permissionFor(String childId) async =>
      permission;

  @override
  Future<HostedAnalysisPermission> setPermission({
    required String childId,
    required bool allowed,
    required String disclosureVersion,
    required bool adultConfirmed,
  }) async {
    calls.add((
      childId: childId,
      allowed: allowed,
      version: disclosureVersion,
      adult: adultConfirmed,
    ));
    return permission = _permission(allowed: allowed);
  }
}

Future<void> _pump(
  WidgetTester tester,
  _Repository repository, {
  double width = 390,
  double textScale = 1,
}) async {
  tester.view.physicalSize = Size(width, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        hostedAnalysisRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: const Scaffold(
          body: SingleChildScrollView(
            child: ParentHostedAnalysisPanel(childId: 'child'),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('online analysis stays off until parent reviews and confirms', (
    tester,
  ) async {
    final repository = _Repository(_permission());
    await _pump(tester, repository);
    expect(find.text('Online analysis is off for this child.'), findsOneWidget);
    await tester.tap(find.text('Review online analysis permission'));
    await tester.pumpAndSettle();
    final allow = find.widgetWithText(FilledButton, 'Allow online analysis');
    expect(tester.widget<FilledButton>(allow).onPressed, isNull);
    expect(repository.calls, isEmpty);
    expect(find.textContaining('Groq in the United States'), findsOneWidget);
    await tester.ensureVisible(find.byType(Checkbox));
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    await tester.tap(allow);
    await tester.pumpAndSettle();
    expect(repository.calls.single, (
      childId: 'child',
      allowed: true,
      version: 'test-disclosure-v1',
      adult: true,
    ));
    expect(find.text('Online analysis is on for this child.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a parent may decline without changing any permission', (
    tester,
  ) async {
    final repository = _Repository(_permission());
    await _pump(tester, repository);
    await tester.tap(find.text('Review online analysis permission'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Keep it off'));
    await tester.pumpAndSettle();
    expect(repository.calls, isEmpty);
    expect(find.text('Online analysis is off for this child.'), findsOneWidget);
  });

  testWidgets('parent may immediately revoke permission for future requests', (
    tester,
  ) async {
    final repository = _Repository(_permission(allowed: true));
    await _pump(tester, repository);
    await tester.tap(find.text('Turn off online analysis'));
    await tester.pumpAndSettle();
    expect(repository.calls.single.allowed, false);
    expect(repository.calls.single.adult, false);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Online analysis is off for this child.'), findsOneWidget);
  });

  testWidgets(
    'approved care is needed but the old local analysis checkbox is not',
    (tester) async {
      final repository = _Repository(_permission(careConsentApproved: false));
      await _pump(tester, repository);
      final review = find.widgetWithText(
        FilledButton,
        'Review online analysis permission',
      );
      expect(tester.widget<FilledButton>(review).onPressed, isNull);
      expect(
        find.textContaining('Approved care consent is needed'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'permission panel and disclosure fit narrow phones at large text',
    (tester) async {
      final repository = _Repository(_permission());
      await _pump(tester, repository, width: 320, textScale: 2);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(
        find.text('Review online analysis permission'),
      );
      await tester.tap(find.text('Review online analysis permission'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.byType(Checkbox));
      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        repository.calls,
        isEmpty,
        reason: 'reading or checking is not a grant',
      );
      final allow = find.widgetWithText(FilledButton, 'Allow online analysis');
      expect(tester.widget<FilledButton>(allow).onPressed, isNotNull);
      await tester.tap(allow);
      await tester.pumpAndSettle();
      expect(repository.calls.single.allowed, true);
      expect(tester.takeException(), isNull);
    },
  );
}
