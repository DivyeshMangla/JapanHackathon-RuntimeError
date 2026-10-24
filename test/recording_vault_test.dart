import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:melo/features/demo_data/data/synthetic_voice.dart';
import 'package:melo/features/recordings/data/recording_vault.dart';

void main() {
  final key = List<int>.generate(32, (i) => i);
  final wav = syntheticVoiceWav(seconds: 0.2, pitchHz: 200);

  test('encrypts with AES-GCM and decrypts back to the same WAV', () async {
    final sealed = await RecordingVault.seal(wav, key);

    expect(String.fromCharCodes(sealed.sublist(0, 4)), 'VPA1');
    expect(sealed.length, 4 + 12 + wav.length + 16);
    expect(sealed.sublist(16, 20), isNot(wav.sublist(0, 4)));
    expect(await RecordingVault.open(sealed, key), wav);
  });

  test('uses a fresh nonce for every file', () async {
    final a = await RecordingVault.seal(wav, key);
    final b = await RecordingVault.seal(wav, key);
    expect(a.sublist(4, 16), isNot(b.sublist(4, 16)));
  });

  test('rejects a tampered file or the wrong key', () async {
    final sealed = await RecordingVault.seal(wav, key);
    final tampered = Uint8List.fromList(sealed)..[40] ^= 1;
    final wrongKey = List<int>.filled(32, 7);

    await expectLater(RecordingVault.open(tampered, key), throwsA(anything));
    await expectLater(RecordingVault.open(sealed, wrongKey), throwsA(anything));
  });

  test('marks encrypted paths by extension', () {
    expect(RecordingVault.isEncrypted('P001_x.wav.vpa'), isTrue);
    expect(RecordingVault.isEncrypted('P001_x.wav'), isFalse);
  });
}
