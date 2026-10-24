import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:melo/features/setup/narration_source.dart';

import 'setup_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('flutter_tts');
  final calls = <MethodCall>[];
  var network = '0';
  var selected = 1;
  setUp(() {
    calls.clear();
    network = '0';
    selected = 1;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          if (call.method == 'getVoices') {
            return [
              {
                'name': 'test-voice',
                'locale': 'hi-IN',
                'network_required': network,
              },
            ];
          }
          if (call.method == 'setVoice') return selected;
          return 1;
        });
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );
  test('missing asset falls back to explicitly offline TTS voice', () async {
    final source = OfflineNarrationSource();
    await source.play('information', 'hi', 'PLACEHOLDER', (_, _) {});
    expect(calls.any((c) => c.method == 'setVoice'), true);
    expect(calls.any((c) => c.method == 'speak'), true);
    await source.dispose();
  });
  test('network-only voice is rejected without speaking', () async {
    network = '1';
    final source = OfflineNarrationSource();
    await expectLater(
      source.play('information', 'hi', 'PLACEHOLDER', (_, _) {}),
      throwsSetupFailure,
    );
    expect(calls.any((c) => c.method == 'speak'), false);
    await source.dispose();
  });
  test(
    'failed offline selection never falls back to default network voice',
    () async {
      selected = 0;
      final source = OfflineNarrationSource();
      await expectLater(
        source.play('information', 'hi', 'PLACEHOLDER', (_, _) {}),
        throwsSetupFailure,
      );
      expect(calls.any((c) => c.method == 'speak'), false);
      await source.dispose();
    },
  );
}
