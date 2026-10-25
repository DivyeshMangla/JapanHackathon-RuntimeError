import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:melo/core/errors/app_failure.dart';
import 'package:melo/core/theme/app_theme.dart';
import 'package:melo/core/utils/l10n.dart';
import 'package:melo/features/useful_words/data/word_repository.dart';
import 'package:melo/features/useful_words/domain/useful_word.dart';
import 'package:melo/features/useful_words/domain/word_audio_device.dart';
import 'package:melo/features/useful_words/presentation/child_word_page.dart';
import 'package:melo/features/useful_words/presentation/word_audio_controller.dart';
import 'package:melo/features/useful_words/presentation/word_review_card.dart';
import 'package:melo/features/useful_words/presentation/word_strings.dart';

class FakeWordDevice implements WordAudioDevice {
  final bytes = Uint8List.fromList([82, 73, 70, 70, 0, 1, 2, 3]);
  final played = <Uint8List>[];
  Completer<bool>? permissionGate;
  Completer<void>? startGate;
  bool allowed = true, active = false, disposed = false;
  int starts = 0, stops = 0, permissionRequests = 0;
  @override
  Future<bool> permission() async {
    permissionRequests++;
    return permissionGate == null ? allowed : permissionGate!.future;
  }

  @override
  Future<void> start() async {
    starts++;
    await startGate?.future;
    active = true;
  }

  @override
  Future<Uint8List?> stop() async {
    stops++;
    active = false;
    return bytes;
  }

  @override
  Future<void> play(Uint8List bytes) async {
    played.add(bytes);
  }

  @override
  Future<void> stopPlayback() async {}
  @override
  Future<void> dispose() async {
    disposed = true;
    active = false;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('voice report generation uses the saved attempt endpoint', () async {
    String? requestedPath;
    String? requestedMethod;
    final repository = WordRepository(
      'child',
      (path, {method = 'GET', data}) async {
        requestedPath = path;
        requestedMethod = method;
        return {'status': 'pending'};
      },
      () => null,
      (_) async {},
    );
    await repository.generateReport('attempt');
    expect(
      requestedPath,
      '/useful-words/patients/child/attempts/attempt/analyze',
    );
    expect(requestedMethod, 'POST');
    expect(WordStrings.reportStatus('complete'), WordStrings.reportReady);
    expect(WordStrings.reportStatus('failed'), WordStrings.reportFailed);
  });
  test(
    'outbox survives failed delivery and repository restart with one immutable submission ID',
    () async {
      String? encryptedStore;
      final submissions = <Map<String, dynamic>>[];
      bool fail = true;
      Future<Map<String, dynamic>> request(
        String path, {
        String method = 'GET',
        Map<String, dynamic>? data,
      }) async {
        submissions.add(data!);
        if (fail) throw const NetworkFailure(NetworkProblem.offline);
        return {'status': 'delivered'};
      }

      WordRepository open() =>
          WordRepository('child', request, () => encryptedStore, (v) async {
            encryptedStore = v;
          });
      final first = open();
      final attempt = await first.queue('word', Uint8List.fromList([1, 2, 3]));
      await expectLater(first.deliver(), throwsA(isA<NetworkFailure>()));
      final restarted = open();
      expect(restarted.pending!.id, attempt.id);
      expect(
        (await restarted.queue('another', Uint8List.fromList([9]))).id,
        attempt.id,
      );
      fail = false;
      await restarted.deliver();
      expect(submissions[0], submissions[1]);
      expect(base64Decode(submissions[1]['audio'] as String), [1, 2, 3]);
      expect(restarted.pending, isNull);
    },
  );
  test(
    'microphone permission is lazy and denial does not start capture',
    () async {
      final device = FakeWordDevice()..allowed = false;
      final audio = WordAudioController(device: device);
      expect(device.permissionRequests, 0);
      await audio.start();
      expect(device.starts, 0);
      expect(audio.message, WordStrings.micDenied);
      audio.dispose();
      await Future<void>.delayed(Duration.zero);
    },
  );
  test(
    'leaving foreground stops capture and preserves original bytes',
    () async {
      final device = FakeWordDevice();
      final session = WordAudioController(device: device);
      await session.start();
      expect(device.active, true);
      session.didChangeAppLifecycleState(AppLifecycleState.inactive);
      await Future<void>.delayed(Duration.zero);
      expect(device.active, false);
      expect(session.recording, false);
      expect(session.audio, device.bytes);
      await session.start();
      expect(device.starts, 1);
      session.dispose();
      await Future<void>.delayed(Duration.zero);
    },
  );
  test(
    'permission and native-start races cannot leave background recording active',
    () async {
      final permission = Completer<bool>();
      final device = FakeWordDevice()..permissionGate = permission;
      final audio = WordAudioController(device: device);
      final starting = audio.start();
      await Future<void>.delayed(Duration.zero);
      audio.didChangeAppLifecycleState(AppLifecycleState.paused);
      permission.complete(true);
      await starting;
      expect(device.starts, 0);
      audio.dispose();
      final gate = Completer<void>(),
          native = FakeWordDevice()..startGate = gate;
      final second = WordAudioController(device: native);
      final pending = second.start();
      await Future<void>.delayed(Duration.zero);
      second.didChangeAppLifecycleState(AppLifecycleState.paused);
      gate.complete();
      await pending;
      expect(native.starts, 1);
      expect(native.stops, 1);
      expect(native.active, false);
      second.dispose();
      await Future<void>.delayed(Duration.zero);
    },
  );

  testWidgets(
    'child can listen, record, replay, delete, re-record, send, retry and skip without speech navigation',
    (tester) async {
      tester.view.physicalSize = const Size(400, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final device = FakeWordDevice();
      final audio = WordAudioController(device: device);
      String? store;
      bool failUpload = true;
      final submissions = <Map<String, dynamic>>[];
      const png =
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAusB9Wl6o1sAAAAASUVORK5CYII=';
      final repo = WordRepository(
        'child',
        (path, {method = 'GET', data}) async {
          if (path.endsWith('/audio')) {
            return {'audio': base64Encode(device.bytes)};
          }
          if (method == 'POST') {
            submissions.add(data!);
            if (failUpload) {
              throw const NetworkFailure(NetworkProblem.offline);
            }
            return {'status': 'delivered'};
          }
          return {
            'consent': true,
            'mockTranscription': true,
            'attempts': [],
            'words': [
              for (final word in ['help', 'water'])
                {
                  'id': word,
                  'word': word,
                  'picture': 'data:image/png;base64,$png',
                },
            ],
          };
        },
        () => store,
        (v) async {
          store = v;
        },
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ChildWordPage(repository: repo, audio: audio),
        ),
      );
      await tester.pumpAndSettle();
      Future<void> tap(String label) async {
        final target = find.text(label).first;
        await tester.ensureVisible(target);
        await tester.tap(target);
        await tester.pumpAndSettle();
      }

      expect(device.permissionRequests, 0);
      await tap(WordStrings.listen);
      expect(device.played.length, 1);
      await tap(WordStrings.record);
      expect(find.text(WordStrings.recording), findsOneWidget);
      await tap(WordStrings.stopRecording);
      await tap(WordStrings.replay);
      expect(device.played.last, device.bytes);
      await tap(WordStrings.delete);
      expect(audio.audio, isNull);
      await tap(WordStrings.record);
      await tap(WordStrings.stopRecording);
      await tap(WordStrings.again);
      await tap(WordStrings.stopRecording);
      expect(device.starts, 3);
      await tap(WordStrings.send);
      expect(find.text(WordStrings.failed), findsOneWidget);
      expect(store, isNotNull);
      failUpload = false;
      await tap(WordStrings.retry);
      expect(find.text(WordStrings.delivered), findsOneWidget);
      expect(submissions.length, 2);
      expect(submissions[0], submissions[1]);
      expect(base64Decode(submissions.last['audio'] as String), device.bytes);
      await tap(WordStrings.next);
      expect(find.text('water'), findsOneWidget);
      await tap(WordStrings.skip);
      expect(find.text(WordStrings.done), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
  testWidgets(
    'a restored failed draft can be deleted and re-recorded on a narrow phone',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final device = FakeWordDevice();
      final audio = WordAudioController(device: device);
      String? store = jsonEncode({
        'id': 'saved-id',
        'wordId': 'help',
        'audio': base64Encode(device.bytes),
      });
      const png =
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAusB9Wl6o1sAAAAASUVORK5CYII=';
      final repo = WordRepository(
        'child',
        (path, {method = 'GET', data}) async => {
          'consent': true,
          'mockTranscription': true,
          'attempts': [],
          'words': [
            {
              'id': 'help',
              'word': 'help',
              'picture': 'data:image/png;base64,$png',
            },
          ],
        },
        () => store,
        (v) async {
          store = v;
        },
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
            child: ChildWordPage(repository: repo, audio: audio),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(WordStrings.failed), findsOneWidget);
      expect(tester.takeException(), isNull);
      final delete = find.text(WordStrings.delete).last;
      await tester.ensureVisible(delete);
      await tester.tap(delete);
      await tester.pumpAndSettle();
      expect(store, isNull);
      expect(audio.audio, isNull);
      final record = find.text(WordStrings.record);
      await tester.scrollUntilVisible(
        record,
        120,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(record);
      await tester.pumpAndSettle();
      await tester.tap(record);
      await tester.pumpAndSettle();
      expect(device.active, true);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      expect(device.active, false);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'therapist sees unassessable report and saves a separate analysis correction',
    (tester) async {
      final device = FakeWordDevice();
      final audio = WordAudioController(device: device);
      Map<String, dynamic>? saved;
      String? playedReference;
      final repo = WordRepository(
        'child',
        (path, {method = 'GET', data}) async {
          if (path.endsWith('/reference')) {
            playedReference = path;
            return {'audio': base64Encode(device.bytes)};
          }
          saved = data;
          return {};
        },
        () => null,
        (value) async {},
      );
      final attempt = WordAttempt.fromJson({
        'id': 'attempt',
        'word': 'help',
        'date': '2026-10-24T12:00:00Z',
        'transcriptionStatus': 'suggested',
        'transcript': 'help',
        'feedback': '',
        'hasFeedbackAudio': false,
        'hasReferenceAudio': true,
        'reviewed': false,
        'analysisReport': {
          'targetWord': 'help',
          'recognizedWord': 'help',
          'textComparison': 'same_text',
          'processingStatus': 'complete',
          'textSimilarity': {
            'status': 'same_text',
            'textSimilarityPercent': 100,
            'characterEditDistance': 0,
            'wordEditDistance': 0,
          },
          'reference': {
            'recognizedText': 'water',
            'recognitionStatus': 'complete',
            'needsReview': true,
          },
          'referenceTranscriptComparison': {
            'status': 'different_text',
            'textSimilarityPercent': 20,
            'characterEditDistance': 4,
            'wordEditDistance': 1,
          },
          'audioComparison': {
            'status': 'timing_only',
            'referenceDurationSeconds': 0.5,
            'attemptDurationSeconds': 0.8,
            'durationRatio': 1.6,
          },
          'validation': 'No validated pronunciation model configured.',
          'limitations': [
            'Recognition confidence is not pronunciation accuracy.',
          ],
        },
      });
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: SingleChildScrollView(
              child: WordReviewCard(
                attempt: attempt,
                repository: repo,
                audio: audio,
                onSaved: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(WordStrings.matchTitle), findsOneWidget);
      expect(find.text('100%'), findsWidgets);
      await tester.tap(find.text(WordStrings.details));
      await tester.pumpAndSettle();
      expect(find.text(WordStrings.reportTitle), findsOneWidget);
      expect(find.text(WordStrings.reportReady), findsOneWidget);
      expect(find.text(WordStrings.regenerateReport), findsOneWidget);
      expect(find.text(WordStrings.sameText), findsOneWidget);
      expect(find.text(WordStrings.accuracyUnavailable), findsOneWidget);
      expect(find.text('${WordStrings.textSimilarity}: 100.0'), findsOneWidget);
      expect(find.text(WordStrings.referenceReview), findsOneWidget);
      expect(find.text('${WordStrings.durationRatio}: 1.60'), findsOneWidget);
      await tester.tap(find.text(WordStrings.referenceOriginal));
      await tester.pumpAndSettle();
      expect(
        playedReference,
        '/useful-words/patients/child/attempts/attempt/reference',
      );
      expect(device.played.single, device.bytes);
      final correction = find.byType(TextField).first;
      await tester.ensureVisible(correction);
      await tester.pumpAndSettle();
      await tester.enterText(
        correction,
        'Therapist observed a different sound.',
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      final assessment = find.byType(
        DropdownButtonFormField<WordTherapistOutcome>,
      );
      await tester.scrollUntilVisible(
        assessment,
        160,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(assessment);
      await tester.pumpAndSettle();
      await tester.tap(find.text(WordStrings.correct).last);
      await tester.pumpAndSettle();
      final save = find.text(WordStrings.review);
      await tester.scrollUntilVisible(
        save,
        160,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(save);
      await tester.pumpAndSettle();
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(
        saved!['analysisCorrection'],
        'Therapist observed a different sound.',
      );
      expect(saved!['therapistOutcome'], 'correct');
      expect(saved!['reviewed'], true);
      expect(saved!.containsKey('analysisReport'), false);
      expect(attempt.analysisReport!.recognizedWord, 'help');
      expect(find.byType(TextField), findsNothing);
      expect(find.text(WordStrings.saved), findsOneWidget);
      expect(audio.audio, isNull);
      await tester.ensureVisible(find.text('Edit feedback'));
      await tester.tap(find.text('Edit feedback'));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsWidgets);
      expect(
        tester.widget<TextField>(find.byType(TextField).first).controller!.text,
        'Therapist observed a different sound.',
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
}
