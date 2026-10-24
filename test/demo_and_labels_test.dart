import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'support/synthetic_voice.dart';

void main() {
  test('synthetic voice is a 44.1 kHz mono 16-bit PCM WAV', () {
    final wav = syntheticVoiceWav(seconds: 0.5, pitchHz: 200);
    final header = ByteData.sublistView(wav, 0, 44);

    expect(String.fromCharCodes(wav.sublist(0, 4)), 'RIFF');
    expect(String.fromCharCodes(wav.sublist(8, 12)), 'WAVE');
    expect(header.getUint16(20, Endian.little), 1);
    expect(header.getUint16(22, Endian.little), 1);
    expect(header.getUint32(24, Endian.little), 44100);
    expect(header.getUint16(34, Endian.little), 16);
    expect(header.getUint32(40, Endian.little), wav.length - 44);
    expect(wav.length - 44, 22050 * 2);
  });
}
