import 'dart:math';
import 'dart:typed_data';

import 'fft.dart';

/// A narrow spectral peak in the background noise.
class SpectralPeak {
  const SpectralPeak({required this.frequencyHz, required this.prominenceDb});

  final double frequencyHz;

  /// How far the peak stands above the neighbouring spectrum.
  final double prominenceDb;
}

/// What kinds of noise make up the background. Thresholds are provisional
/// heuristics for the developer screen, to be tuned on real devices.
class NoiseReport {
  const NoiseReport({
    required this.ready,
    this.rumbleShare = 0,
    this.hum,
    this.tone,
    this.broadbandBands = 0,
    this.fluctuationDb,
    this.transients = 0,
  });

  static const rumbleMinShare = 0.5;
  static const humMinProminenceDb = 6.0;
  static const toneMinProminenceDb = 12.0;
  static const broadbandMinBands = 10;
  static const fluctuationMinDb = 3.0;

  /// Third-octave bands checked for broadband noise, 250 Hz to 8 kHz.
  static const broadbandTotalBands = 16;

  /// Seconds over which clicks and knocks are counted.
  static const transientWindowSec = 30;

  /// False until enough background has been heard to judge.
  final bool ready;

  /// Fraction of background power below 100 Hz (traffic, handling, wind).
  final double rumbleShare;

  /// Mains hum at 50 or 60 Hz and its harmonics.
  final SpectralPeak? hum;

  /// Strongest steady tone above 200 Hz (fan whine, electronics).
  final SpectralPeak? tone;

  /// Third-octave bands within 10 dB of the loudest (fans, AC, hiss).
  final int broadbandBands;

  /// Spread of background level, in dB (TV, other voices, traffic).
  final double? fluctuationDb;

  /// Short loud bursts in the last [transientWindowSec] seconds.
  final int transients;

  bool get hasRumble => ready && rumbleShare >= rumbleMinShare;
  bool get hasHum => ready && hum != null;
  bool get hasTone => ready && tone != null;
  bool get isBroadband => ready && broadbandBands >= broadbandMinBands;
  bool get isFluctuating => (fluctuationDb ?? 0) >= fluctuationMinDb;
  bool get hasTransients => transients > 0;
}

/// Classifies background noise from a high-resolution spectrum (about 11 Hz
/// per bin, fine enough to tell 50 Hz hum from 60 Hz) of background-only
/// audio, plus the level history.
class NoiseProfiler {
  NoiseProfiler({
    required this.sampleRate,
    required this.blockSec,
    this.frameSize = 4096,
  }) : _fft = Fft(frameSize),
       _window = hannWindow(frameSize),
       _real = Float64List(frameSize),
       _imag = Float64List(frameSize),
       _background = Float64List(frameSize ~/ 2 + 1);

  static const _spectrumSmoothing = 0.85;
  static const _readyFrames = 10;
  static const _fluctuationSec = 5;

  /// A burst must rise this far above the floor, and last at most
  /// [_maxTransientSec], to count as a click rather than voice.
  static const _transientRiseDb = 15.0;
  static const _transientEndDb = 10.0;
  static const _maxTransientSec = 0.1;

  /// The microphone pops as it starts, so bursts this early are ignored.
  static const _settleSec = 1.0;

  /// Background quieter than this is digital silence (a muted or virtual
  /// microphone), where every band is equally empty and nothing can be
  /// classified.
  static const _silenceDb = -90.0;

  final int sampleRate;
  final double blockSec;
  final int frameSize;
  final Fft _fft;
  final Float64List _window;
  final Float64List _real;
  final Float64List _imag;
  final Float64List _background;
  final _buffer = <double>[];
  bool _bufferAllBackground = true;
  int _backgroundFrames = 0;
  int _block = 0;
  int _burstBlocks = 0;
  final _backgroundLevels = <double>[];
  final _transientBlocks = <int>[];
  NoiseReport? _spectral;
  int _spectralAt = -1;

  double get binHz => sampleRate / frameSize;

  /// Adds one analysed block. [background] marks blocks without voice.
  void add(
    Float32List samples, {
    required bool background,
    required double levelDb,
    required double floorDb,
  }) {
    _block++;
    _trackTransient(levelDb, floorDb);
    if (background) {
      _backgroundLevels.add(levelDb);
      final limit = (_fluctuationSec / blockSec).round();
      if (_backgroundLevels.length > limit) _backgroundLevels.removeAt(0);
    }

    _buffer.addAll(samples);
    _bufferAllBackground &= background;
    if (_buffer.length >= frameSize) {
      if (_bufferAllBackground) _addBackgroundFrame();
      _buffer.clear();
      _bufferAllBackground = true;
    }
  }

  void _trackTransient(double levelDb, double floorDb) {
    if (_block * blockSec < _settleSec) return;
    if (levelDb > floorDb + _transientRiseDb) {
      _burstBlocks++;
    } else if (_burstBlocks > 0 && levelDb < floorDb + _transientEndDb) {
      if (_burstBlocks * blockSec <= _maxTransientSec) {
        _transientBlocks.add(_block);
      }
      _burstBlocks = 0;
    }
    final oldest = _block - (NoiseReport.transientWindowSec / blockSec);
    _transientBlocks.removeWhere((b) => b < oldest);
  }

  void _addBackgroundFrame() {
    for (var i = 0; i < frameSize; i++) {
      _real[i] = _buffer[i] * _window[i];
      _imag[i] = 0;
    }
    _fft.forward(_real, _imag);
    for (var k = 0; k < _background.length; k++) {
      final power = _real[k] * _real[k] + _imag[k] * _imag[k];
      _background[k] = _backgroundFrames == 0
          ? power
          : _spectrumSmoothing * _background[k] +
                (1 - _spectrumSmoothing) * power;
    }
    _backgroundFrames++;
  }

  NoiseReport get report {
    // The spectral checks cost a few milliseconds, so they are redone only
    // when a new background frame has arrived.
    if (_spectralAt != _backgroundFrames) {
      _spectral = _backgroundFrames < _readyFrames
          ? const NoiseReport(ready: false)
          : _analyseSpectrum();
      _spectralAt = _backgroundFrames;
    }
    final spectral = _spectral!;
    return NoiseReport(
      ready: spectral.ready,
      rumbleShare: spectral.rumbleShare,
      hum: spectral.hum,
      tone: spectral.tone,
      broadbandBands: spectral.broadbandBands,
      fluctuationDb: _fluctuation(),
      transients: _transientBlocks.length,
    );
  }

  NoiseReport _analyseSpectrum() {
    final levels = _backgroundLevels;
    if (levels.isNotEmpty && levels.reduce(max) < _silenceDb) {
      return const NoiseReport(ready: true);
    }
    final hum = _findHum();
    return NoiseReport(
      ready: true,
      rumbleShare: _bandPower(20, 100) / max(_bandPower(20, 16000), 1e-30),
      hum: hum,
      tone: _findTone(hum?.frequencyHz),
      broadbandBands: _broadbandBands(),
    );
  }

  double _bandPower(double lowHz, double highHz) {
    var sum = 0.0;
    final last = min((highHz / binHz).floor(), _background.length - 1);
    for (var k = max((lowHz / binHz).ceil(), 1); k <= last; k++) {
      sum += _background[k];
    }
    return sum;
  }

  /// Prominence of the peak near [bin] over the median of the bins between
  /// [inner] and [outer] away on both sides.
  double _prominenceDb(int bin, int inner, int outer) {
    var peak = 0.0;
    for (var k = bin - 1; k <= bin + 1; k++) {
      if (k > 0 && k < _background.length) peak = max(peak, _background[k]);
    }
    final neighbours = <double>[
      for (var offset = inner; offset <= outer; offset++) ...[
        if (bin - offset > 0) _background[bin - offset],
        if (bin + offset < _background.length) _background[bin + offset],
      ],
    ]..sort();
    if (neighbours.isEmpty) return 0;
    return powerDb(peak) - powerDb(neighbours[neighbours.length ~/ 2]);
  }

  SpectralPeak? _findHum() {
    SpectralPeak? best;
    for (final mains in const [50.0, 60.0]) {
      final prominences = [
        for (var h = 1; h <= 5; h++)
          _prominenceDb((h * mains / binHz).round(), 3, 4),
      ]..sort();
      // Mean of the three strongest harmonics: phone microphones often roll
      // off the fundamental, so it alone is not reliable.
      final score = prominences.skip(2).reduce((a, b) => a + b) / 3;
      if (best == null || score > best.prominenceDb) {
        best = SpectralPeak(frequencyHz: mains, prominenceDb: score);
      }
    }
    return best != null && best.prominenceDb >= NoiseReport.humMinProminenceDb
        ? best
        : null;
  }

  SpectralPeak? _findTone(double? humHz) {
    SpectralPeak? best;
    final last = min((8000 / binHz).floor(), _background.length - 2);
    for (var k = (200 / binHz).ceil(); k <= last; k++) {
      if (_background[k] < _background[k - 1] ||
          _background[k] < _background[k + 1]) {
        continue;
      }
      final hz = k * binHz;
      if (humHz != null) {
        final harmonic = (hz / humHz).round() * humHz;
        if ((hz - harmonic).abs() <= 2 * binHz) continue;
      }
      final prominence = _prominenceDb(k, 4, 20);
      if (best == null || prominence > best.prominenceDb) {
        best = SpectralPeak(frequencyHz: hz, prominenceDb: prominence);
      }
    }
    return best != null && best.prominenceDb >= NoiseReport.toneMinProminenceDb
        ? best
        : null;
  }

  int _broadbandBands() {
    final bands = [
      for (var i = 0; i < NoiseReport.broadbandTotalBands; i++)
        () {
          final centre = 250 * pow(2, i / 3).toDouble();
          final halfBand = pow(2, 1 / 6).toDouble();
          return powerDb(_bandPower(centre / halfBand, centre * halfBand));
        }(),
    ];
    final loudest = bands.reduce(max);
    return bands.where((b) => b >= loudest - 10).length;
  }

  double? _fluctuation() {
    if (_backgroundLevels.length < (2 / blockSec).round()) return null;
    final mean =
        _backgroundLevels.reduce((a, b) => a + b) / _backgroundLevels.length;
    final variance =
        _backgroundLevels
            .map((l) => (l - mean) * (l - mean))
            .reduce((a, b) => a + b) /
        _backgroundLevels.length;
    return sqrt(variance);
  }
}
