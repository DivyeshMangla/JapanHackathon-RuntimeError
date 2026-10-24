import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:melo/core/theme/app_theme.dart';
import 'package:melo/core/utils/l10n.dart';
import 'package:melo/features/exercises/data/clip_cue_speaker.dart';
import 'package:melo/features/exercises/domain/cue_speaker.dart';
import 'package:melo/features/exercises/domain/exercise_demo.dart';
import 'package:melo/features/exercises/presentation/demos/exercise_demo_player.dart';
import 'package:melo/features/exercises/presentation/demos/exercise_demos.dart';

class _RecordingSpeaker implements CueSpeaker {
  final spoken = <DemoCue>[];
  var stops = 0;

  @override
  Future<void> speak(DemoCue cue) async => spoken.add(cue);

  @override
  Future<void> stop() async => stops++;
}

void main() {
  const script = diaphragmaticBreathingScript;

  test('a breathing cycle is a 4 s inhale then a 6 s exhale', () {
    expect(script.cycle, const Duration(seconds: 10));
    expect(script.total(3), const Duration(seconds: 30));
  });

  test('starts at the beginning of the first inhale', () {
    final position = script.positionAt(Duration.zero, 3);
    expect(position.repetition, 1);
    expect(position.phase.cue, DemoCue.breatheIn);
    expect(position.progress, 0);
    expect(position.remaining, const Duration(seconds: 4));
    expect(position.finished, isFalse);
  });

  test('moves into the exhale and then the next repetition', () {
    final exhale = script.positionAt(const Duration(seconds: 7), 3);
    expect(exhale.repetition, 1);
    expect(exhale.phase.cue, DemoCue.breatheOut);
    expect(exhale.progress, closeTo(0.5, 1e-9));
    expect(exhale.remaining, const Duration(seconds: 3));

    final second = script.positionAt(const Duration(seconds: 11), 3);
    expect(second.repetition, 2);
    expect(second.phase.cue, DemoCue.breatheIn);
    expect(second.progress, closeTo(0.25, 1e-9));
  });

  test('finishes after the last repetition and never runs past it', () {
    final end = script.positionAt(const Duration(seconds: 45), 3);
    expect(end.finished, isTrue);
    expect(end.repetition, 3);
    expect(end.phase.cue, DemoCue.breatheOut);
    expect(end.progress, 1);
    expect(end.remaining, Duration.zero);
  });

  test('treats fewer than one repetition as one', () {
    expect(script.positionAt(const Duration(seconds: 10), 0).finished, isTrue);
    expect(script.positionAt(const Duration(seconds: 5), 0).finished, isFalse);
  });

  Future<_RecordingSpeaker> pumpPlayer(WidgetTester tester, int reps) async {
    final speaker = _RecordingSpeaker();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [cueSpeakerProvider.overrideWithValue(speaker)],
        child: MaterialApp(
          theme: AppTheme.light,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: ExerciseDemoPlayer(
                demo: exerciseDemoFor('ex-breathing')!,
                repetitions: reps,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return speaker;
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    await tester.ensureVisible(find.text(text));
    await tester.tap(find.text(text));
    await tester.pump();
  }

  testWidgets('the player counts down cues and repetitions', (tester) async {
    await pumpPlayer(tester, 2);
    expect(find.text('Ready when you are'), findsOneWidget);
    expect(find.text('Rep 1 of 2'), findsOneWidget);

    await tapText(tester, 'Start');
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Breathe in'), findsOneWidget);
    expect(find.text('Pause'), findsOneWidget);

    await tester.pump(const Duration(seconds: 4));
    expect(find.text('Breathe out'), findsOneWidget);

    await tester.pump(const Duration(seconds: 6));
    expect(find.text('Rep 2 of 2'), findsOneWidget);

    await tester.pump(const Duration(seconds: 10));
    expect(find.text('All repetitions done'), findsOneWidget);
    expect(find.text('Start again'), findsOneWidget);
  });

  testWidgets('the voice speaks each cue once as it starts', (tester) async {
    final speaker = await pumpPlayer(tester, 3);
    await tapText(tester, 'Start');
    for (var second = 0; second < 31; second++) {
      await tester.pump(const Duration(seconds: 1));
    }
    expect(speaker.spoken, [
      for (var rep = 0; rep < 3; rep++) ...[
        DemoCue.breatheIn,
        DemoCue.breatheOut,
      ],
    ]);
  });

  testWidgets('pausing silences the voice and muting stops cues', (
    tester,
  ) async {
    final speaker = await pumpPlayer(tester, 3);
    await tapText(tester, 'Start');
    await tester.pump(const Duration(seconds: 1));
    await tapText(tester, 'Pause');
    expect(speaker.stops, greaterThan(0));

    await tester.tap(find.byTooltip('Mute voice cues'));
    await tester.pump();
    final spokenBefore = speaker.spoken.length;
    await tapText(tester, 'Resume');
    await tester.pump(const Duration(seconds: 10));
    expect(speaker.spoken.length, spokenBefore);
    expect(find.byTooltip('Turn on voice cues'), findsOneWidget);
  });

  test('every cue has a bundled voice clip', () {
    for (final cue in DemoCue.values) {
      final asset = ClipCueSpeaker.assetFor(cue);
      expect(File(asset).existsSync(), isTrue, reason: asset);
    }
  });

  test('only diaphragmatic breathing has a demo so far', () {
    expect(exerciseDemoFor('ex-breathing'), isNotNull);
    expect(exerciseDemoFor('ex-humming'), isNull);
  });
}
