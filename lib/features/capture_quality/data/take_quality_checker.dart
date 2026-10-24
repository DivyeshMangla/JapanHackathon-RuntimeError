import 'dart:io';
import 'dart:isolate';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/errors/guard.dart';
import '../domain/take_quality.dart';
import 'wav_decoder.dart';

/// Measures a finished take from its WAV file, off the UI isolate: a
/// three-minute take is about eight million samples.
class TakeQualityChecker {
  const TakeQualityChecker();

  Future<TakeQuality> check(String wavPath) => guard(() async {
    final bytes = await File(wavPath).readAsBytes();
    return Isolate.run(() {
      final wav = decodeWav(bytes);
      return assessTake(wav.samples, wav.sampleRate);
    });
  }, RecordingFailure.new);
}

final takeQualityCheckerProvider = Provider<TakeQualityChecker>(
  (ref) => const TakeQualityChecker(),
);
