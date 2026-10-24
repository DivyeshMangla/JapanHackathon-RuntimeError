import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:melo/core/utils/l10n.dart';
import 'package:melo/features/demo_data/data/synthetic_voice.dart';

void main() {
  setUpAll(() => initializeDateFormatting('en'));

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

  test('weekday sets are described in plain words', () {
    final l10n = lookupAppLocalizations(const Locale('en'));
    expect(l10n.describeWeekdays({1, 2, 3, 4, 5, 6, 7}), 'Every day');
    expect(l10n.describeWeekdays({1, 2, 3, 4, 5}), 'Weekdays');
    expect(l10n.describeWeekdays({5, 1, 3}), 'Mon, Wed, Fri');
  });
}
