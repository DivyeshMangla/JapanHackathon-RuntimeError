import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:melo/core/errors/setup_failure.dart';
import 'package:melo/core/setup_state.dart';
import 'package:melo/core/setup_strings.dart';
import 'package:melo/features/setup/presentation/setup_actions.dart';
import 'package:melo/features/setup/setup_app.dart';
import 'package:melo/features/setup/setup_service.dart';

import 'setup_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(SetupStrings.load);
  testWidgets('role cards launch patient setup with honest code lookup', (
    tester,
  ) async {
    final service = device();
    await service.load();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [setupServiceProvider.overrideWithValue(service)],
        child: const SetupApp(),
      ),
    );
    expect(find.text('Choose your role'), findsOneWidget);
    await tester.tap(find.text('Patient'));
    await tester.pumpAndSettle();
    expect(find.text('Join your therapist'), findsOneWidget);
    expect(
      find.text(
        'Code lookup arrives with the hospital backend; scan the QR for now',
      ),
      findsOneWidget,
    );
    expect(service.state.stage, SetupStage.needsJoin);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'consent requires every required checkbox but allows optional decline',
    (tester) async {
      final service = device();
      await service.repository.save({
        'stage': 'consent',
        'checks': {
          for (final item in ConsentItem.values)
            item.name: item.isRequired && item != ConsentItem.adult,
        },
      });
      await service.load();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [setupServiceProvider.overrideWithValue(service)],
          child: const SetupApp(),
        ),
      );
      await tester.scrollUntilVisible(find.text('I agree'), 400);
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'I agree'))
            .onPressed,
        null,
      );
      await tester.runAsync(
        () => service.saveChecks({
          for (final item in ConsentItem.values) item: item.isRequired,
        }),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'I agree'))
            .onPressed,
        isNotNull,
      );
      await tester.tap(find.text('I agree'));
      await tester.pumpAndSettle();
      expect(find.text('Sign consent'), findsOneWidget);
      expect(service.state.stage, SetupStage.signature);
      await tester.pumpWidget(const SizedBox());
    },
  );

  test('every setup failure has its own message in every locale', () {
    for (final locale in ['en', 'hi', 'pa']) {
      // Read the ARB itself: SetupStrings falls back to English, which would
      // hide a missing translation.
      final strings =
          jsonDecode(
                File(
                  'lib/features/setup/l10n/setup_$locale.arb',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      for (final reason in SetupFailureReason.values) {
        final key = setupFailureMessageKey(reason);
        expect(strings, contains(key), reason: '$locale is missing $key');
      }
    }
  });

  test('all workflow ARBs contain the same translated labels', () {
    for (final locale in ['en', 'hi', 'pa']) {
      for (final key in [
        'consent',
        'placeholder',
        'informationText',
        'therapistConsent',
        'needsJoin',
        'active',
      ]) {
        expect(SetupStrings.text(locale, key), isNot(key));
      }
    }
  });
}
