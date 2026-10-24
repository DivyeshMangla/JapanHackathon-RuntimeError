import 'dart:math';
import 'dart:typed_data';

/// Converts little-endian 16-bit PCM bytes to samples in -1..1.
Float32List pcm16ToSamples(Uint8List bytes) {
  final data = ByteData.sublistView(bytes);
  final samples = Float32List(bytes.length ~/ 2);
  for (var i = 0; i < samples.length; i++) {
    samples[i] = data.getInt16(i * 2, Endian.little) / 32768;
  }
  return samples;
}

/// Level in dBFS, floored at [AudioAnalyzer.silenceDb] for digital silence.
double levelDb(Float32List samples) {
  if (samples.isEmpty) return AudioAnalyzer.silenceDb;
  var sum = 0.0;
  for (final s in samples) {
    sum += s * s;
  }
  final rms = sqrt(sum / samples.length);
  return rms <= 0
      ? AudioAnalyzer.silenceDb
      : max(AudioAnalyzer.silenceDb, 20 * log(rms) / ln10);
}

/// Second-order Butterworth high-pass. Removes rumble and mains hum below the
/// lowest speaking pitch.
class HighPassFilter {
  HighPassFilter({required double cutoffHz, required double sampleRate}) {
    final w = 2 * pi * cutoffHz / sampleRate;
    final alpha = sin(w) / (2 * sqrt1_2);
    final cosW = cos(w);
    final a0 = 1 + alpha;
    _b0 = (1 + cosW) / 2 / a0;
    _b1 = -(1 + cosW) / a0;
    _b2 = _b0;
    _a1 = -2 * cosW / a0;
    _a2 = (1 - alpha) / a0;
  }

  late final double _b0, _b1, _b2, _a1, _a2;
  double _x1 = 0, _x2 = 0, _y1 = 0, _y2 = 0;

  Float32List process(Float32List input) {
    final out = Float32List(input.length);
    for (var i = 0; i < input.length; i++) {
      final x = input[i];
      final y = _b0 * x + _b1 * _x1 + _b2 * _x2 - _a1 * _y1 - _a2 * _y2;
      _x2 = _x1;
      _x1 = x;
      _y2 = _y1;
      _y1 = y;
      out[i] = y;
    }
    return out;
  }
}

/// Background level estimate: a low percentile of recent block levels, so
/// speech peaks do not raise it.
class NoiseFloorTracker {
  NoiseFloorTracker({required this.windowBlocks, this.percentile = 0.1});

  final int windowBlocks;
  final double percentile;
  final _levels = <double>[];

  void add(double levelDb) {
    _levels.add(levelDb);
    if (_levels.length > windowBlocks) _levels.removeAt(0);
  }

  double? get floorDb {
    if (_levels.isEmpty) return null;
    final sorted = [..._levels]..sort();
    return sorted[(percentile * (sorted.length - 1)).round()];
  }
}

class AudioBlock {
  const AudioBlock({
    required this.samples,
    required this.levelDb,
    required this.filteredLevelDb,
    required this.noiseFloorDb,
    required this.voiced,
  });

  /// The unprocessed block.
  final Float32List samples;
  final double levelDb;

  /// Level after the rumble high-pass, used for voice detection.
  final double filteredLevelDb;
  final double noiseFloorDb;

  /// True when the block stands [AudioAnalyzer.voiceMarginDb] above the
  /// noise floor; everything else is treated as background.
  final bool voiced;
}

/// Quality figures from research doc 4.3, accumulated since listening began.
class AudioQuality {
  const AudioQuality({
    required this.noiseFloorDb,
    required this.snrDb,
    required this.clippedFraction,
    required this.phonationSec,
    required this.longestPhonationSec,
  });

  final double? noiseFloorDb;

  /// Recent voiced level minus the noise floor; null until there is voice.
  final double? snrDb;
  final double clippedFraction;

  /// Length of the current continuous voicing.
  final double phonationSec;
  final double longestPhonationSec;
}

/// Splits incoming audio into fixed blocks and, for each block, measures
/// level, tracks the noise floor and decides whether it holds voice. It never
/// alters the audio.
class AudioAnalyzer {
  AudioAnalyzer({required this.sampleRate, this.blockSize = 1024})
    : _highPass = HighPassFilter(
        cutoffHz: 80,
        sampleRate: sampleRate.toDouble(),
      ),
      _floor = NoiseFloorTracker(
        windowBlocks: (noiseWindowSec * sampleRate / blockSize).round(),
      );

  static const silenceDb = -100.0;

  /// Long enough that a held maximum-phonation vowel (often 20 s or more)
  /// still leaves background-only blocks in the window.
  static const noiseWindowSec = 15;

  /// A block counts as voice this far above the noise floor.
  static const voiceMarginDb = 10.0;

  /// A sample at or above this magnitude counts as clipped.
  static const clipLevel = 0.999;

  final int sampleRate;
  final int blockSize;
  final HighPassFilter _highPass;
  final NoiseFloorTracker _floor;
  final _pending = <double>[];
  final _recentVoiced = <double>[];
  int _samples = 0;
  int _clipped = 0;
  int _voicedBlocks = 0;
  int _silentRun = 0;
  double _longestPhonation = 0;

  double get blockSec => blockSize / sampleRate;

  /// Analyses [samples], returning one [AudioBlock] per completed block.
  List<AudioBlock> add(Float32List samples) {
    _pending.addAll(samples);
    final blocks = <AudioBlock>[];
    while (_pending.length >= blockSize) {
      final block = Float32List.fromList(_pending.sublist(0, blockSize));
      _pending.removeRange(0, blockSize);
      blocks.add(_analyse(block));
    }
    return blocks;
  }

  AudioQuality get quality {
    final floor = _floor.floorDb;
    final voiced = _recentVoiced.isEmpty
        ? null
        : _recentVoiced.reduce((a, b) => a + b) / _recentVoiced.length;
    return AudioQuality(
      noiseFloorDb: floor,
      snrDb: voiced == null || floor == null ? null : voiced - floor,
      clippedFraction: _samples == 0 ? 0 : _clipped / _samples,
      phonationSec: _voicedBlocks * blockSec,
      longestPhonationSec: _longestPhonation,
    );
  }

  AudioBlock _analyse(Float32List raw) {
    _samples += raw.length;
    for (final s in raw) {
      if (s.abs() >= clipLevel) _clipped++;
    }

    final filteredDb = levelDb(_highPass.process(raw));
    _floor.add(filteredDb);
    final floor = _floor.floorDb ?? filteredDb;
    final voiced = filteredDb > floor + voiceMarginDb;
    _trackPhonation(voiced, filteredDb);

    return AudioBlock(
      samples: raw,
      levelDb: levelDb(raw),
      filteredLevelDb: filteredDb,
      noiseFloorDb: floor,
      voiced: voiced,
    );
  }

  void _trackPhonation(bool voiced, double levelDb) {
    // Short dips (under 200 ms) do not end a held sound.
    final allowedGap = (0.2 / blockSec).ceil();
    if (voiced) {
      _voicedBlocks += 1 + _silentRun;
      _silentRun = 0;
      _recentVoiced.add(levelDb);
      if (_recentVoiced.length > (1 / blockSec).round()) {
        _recentVoiced.removeAt(0);
      }
      _longestPhonation = max(_longestPhonation, _voicedBlocks * blockSec);
    } else if (_voicedBlocks > 0 && ++_silentRun > allowedGap) {
      _voicedBlocks = 0;
      _silentRun = 0;
      // SNR describes the current sound only, not one that has ended.
      _recentVoiced.clear();
    }
  }
}
