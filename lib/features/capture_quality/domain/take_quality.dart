import 'dart:typed_data';

import 'audio_analyzer.dart';

enum TakeIssue { noVoice, noisy, clipped, moved }

enum TakeRating { good, acceptable, poor }

/// Whether a finished take is fit for voice analysis, using the research
/// doc 4.3 thresholds. Advisory: the patient can still keep a poor take.
class TakeQuality {
  const TakeQuality({
    required this.snrDb,
    required this.clippedFraction,
    required this.voicedSec,
    this.movingFraction,
  });

  /// Voice measures are reliable from here.
  static const goodSnrDb = 42.0;

  /// Below this, jitter, shimmer and HNR are not usable.
  static const minSnrDb = 30.0;
  static const maxClippedFraction = 0.001;
  static const minVoicedSec = 0.3;

  /// Provisional, like the motion thresholds it relies on.
  static const maxMovingFraction = 0.25;

  /// Mean voiced level over the noise floor; null when no voice was heard.
  final double? snrDb;
  final double clippedFraction;
  final double voicedSec;

  /// Share of the take with the phone moving; null without motion sensors.
  final double? movingFraction;

  TakeQuality withMotion(double? movingFraction) => TakeQuality(
    snrDb: snrDb,
    clippedFraction: clippedFraction,
    voicedSec: voicedSec,
    movingFraction: movingFraction,
  );

  List<TakeIssue> get issues => [
    if (voicedSec < minVoicedSec) TakeIssue.noVoice,
    if (snrDb case final snr? when snr < minSnrDb) TakeIssue.noisy,
    if (clippedFraction >= maxClippedFraction) TakeIssue.clipped,
    if ((movingFraction ?? 0) > maxMovingFraction) TakeIssue.moved,
  ];

  TakeRating get rating => issues.isNotEmpty
      ? TakeRating.poor
      : (snrDb ?? 0) >= goodSnrDb
      ? TakeRating.good
      : TakeRating.acceptable;
}

/// Measures a whole take. The noise floor is the quietest tenth of blocks,
/// which the half-second lead-in before each take provides.
TakeQuality assessTake(
  Float32List samples,
  int sampleRate, {
  int blockSize = 1024,
}) {
  final highPass = HighPassFilter(
    cutoffHz: 80,
    sampleRate: sampleRate.toDouble(),
  );
  final levels = <double>[];
  var clipped = 0;
  for (var start = 0; start + blockSize <= samples.length; start += blockSize) {
    final block = Float32List.sublistView(samples, start, start + blockSize);
    for (final s in block) {
      if (s.abs() >= AudioAnalyzer.clipLevel) clipped++;
    }
    levels.add(levelDb(highPass.process(block)));
  }
  if (levels.isEmpty) {
    return const TakeQuality(snrDb: null, clippedFraction: 0, voicedSec: 0);
  }

  final sorted = [...levels]..sort();
  final floor = sorted[((sorted.length - 1) * 0.1).round()];
  final voiced = levels
      .where((l) => l > floor + AudioAnalyzer.voiceMarginDb)
      .toList();
  return TakeQuality(
    snrDb: voiced.isEmpty
        ? null
        : voiced.reduce((a, b) => a + b) / voiced.length - floor,
    clippedFraction: clipped / (levels.length * blockSize),
    voicedSec: voiced.length * blockSize / sampleRate,
  );
}
