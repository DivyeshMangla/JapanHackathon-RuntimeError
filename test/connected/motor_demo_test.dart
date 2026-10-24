import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:melo/core/theme/app_theme.dart';
import 'package:melo/core/utils/l10n.dart';
import 'package:melo/features/connected/domain/connected_models.dart';
import 'package:melo/features/connected/presentation/motor_demo.dart';

void main() {
  const exercise = LibraryExercise(
    id: 'motor-letter',
    name: 'My letter L',
    description: 'Write L',
    isMotor: true,
    steps: ['Start at the top.', 'Draw down, then across.'],
    strokes: [
      [
        [0.3, 0.15],
        [0.3, 0.85],
      ],
      [
        [0.3, 0.85],
        [0.75, 0.85],
      ],
    ],
  );
  Widget app({bool reducedMotion = false}) => MaterialApp(
    theme: AppTheme.light,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reducedMotion),
      child: const Scaffold(
        body: SingleChildScrollView(child: MotorDemo(exercise: exercise)),
      ),
    ),
  );

  testWidgets(
    'writing demonstration presents ordered instructions and can replay',
    (tester) async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      final board = tester.getSize(
        find.descendant(
          of: find.byType(AspectRatio),
          matching: find.byType(CustomPaint),
        ),
      );
      expect(board.width / board.height, closeTo(1.5, 0.01));
      expect(find.text('1. Start at the top.'), findsOneWidget);
      expect(find.text('2. Draw down, then across.'), findsOneWidget);
      await tester.tap(find.text('Show me the strokes'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      expect(tester.binding.hasScheduledFrame, isTrue);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('reduced motion keeps a complete static guide', (tester) async {
    await tester.pumpWidget(app(reducedMotion: true));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Show me the strokes'));
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(find.text('2. Draw down, then across.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
