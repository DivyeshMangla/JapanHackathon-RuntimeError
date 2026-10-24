import 'dart:math';
import 'dart:typed_data';

import '../../capture_quality/domain/audio_analyzer.dart';
import '../../capture_quality/domain/fft.dart';
import '../../capture_quality/domain/noise_profiler.dart';
import '../../capture_quality/domain/spectral_denoiser.dart';

typedef WaveColumn = ({double min, double max});

/// One block of the live display: the raw input and the denoised signal,
/// aligned in time.
class LiveAudioFrame {
  const LiveAudioFrame({
    required this.rawColumns,
    required this.cleanColumns,
    required this.levelDb,
    required this.cleanLevelDb,
    required this.noiseFloorDb,
    required this.voiced,
  });

  final List<WaveColumn> rawColumns;
  final List<WaveColumn> cleanColumns;
  final double levelDb;
  final double cleanLevelDb;
  final double noiseFloorDb;
  final bool voiced;
}

/// Spectra on a shared log-frequency axis, in dB per Hz.
class SpectrumView {
  const SpectrumView({
    required this.input,
    required this.noise,
    required this.clean,
  });

  static const minHz = 50.0;
  static const maxHz = 16000.0;
  static const points = 128;

  final List<double> input;
  final List<double> noise;
  final List<double> clean;
}

/// What the cleaning achieved, for the readouts.
class CleaningStats {
  const CleaningStats({required this.noiseRemovedDb, required this.cleanSnrDb});

  /// How far background noise was lowered, in dB.
  final double? noiseRemovedDb;

  /// Signal to noise of the denoised signal; null until there is voice.
  final double? cleanSnrDb;
}

/// Runs microphone audio through voice detection ([AudioAnalyzer]), log-MMSE
/// noise reduction ([SpectralDenoiser]) and noise classification
/// ([NoiseProfiler]) for the developer screen. Display only.
class LiveAudioPipeline {
  LiveAudioPipeline({required int sampleRate})
    : _analyzer = AudioAnalyzer(sampleRate: sampleRate),
      _denoiser = SpectralDenoiser(sampleRate: sampleRate),
      _highPass = HighPassFilter(
        cutoffHz: 80,
        sampleRate: sampleRate.toDouble(),
      ) {
    _profiler = NoiseProfiler(
      sampleRate: sampleRate,
      blockSec: _analyzer.blockSec,
    );
    _cleanFloor = NoiseFloorTracker(
      windowBlocks: (AudioAnalyzer.noiseWindowSec / _analyzer.blockSec).round(),
    );
    _rawDelay = Float32List(_denoiser.latencySamples);
  }

  static const columnsPerBlock = 8;

  /// Smoothing of the noise-removed readout across background blocks.
  static const _reductionSmoothing = 0.9;

  final AudioAnalyzer _analyzer;
  final SpectralDenoiser _denoiser;
  final HighPassFilter _highPass;
  late final NoiseProfiler _profiler;
  late final NoiseFloorTracker _cleanFloor;

  /// The raw signal is delayed by the denoiser's latency so both waveforms
  /// line up on screen.
  late Float32List _rawDelay;
  final _recentCleanVoiced = <double>[];
  double? _noiseRemovedDb;

  AudioQuality get quality => _analyzer.quality;

  NoiseReport get noiseReport => _profiler.report;

  List<LiveAudioFrame> add(Float32List samples) => [
    for (final block in _analyzer.add(samples)) _process(block),
  ];

  LiveAudioFrame _process(AudioBlock block) {
    final clean = _highPass.process(
      _denoiser.process(block.samples, speech: block.voiced),
    );
    final raw = _delayed(block.samples);
    final cleanDb = levelDb(clean);
    final rawDb = levelDb(raw);
    _cleanFloor.add(cleanDb);
    _profiler.add(
      block.samples,
      background: !block.voiced,
      levelDb: block.filteredLevelDb,
      floorDb: block.noiseFloorDb,
    );
    _trackCleaning(block.voiced, rawDb, cleanDb);

    return LiveAudioFrame(
      rawColumns: waveColumns(raw, columnsPerBlock),
      cleanColumns: waveColumns(clean, columnsPerBlock),
      levelDb: block.levelDb,
      cleanLevelDb: cleanDb,
      noiseFloorDb: block.noiseFloorDb,
      voiced: block.voiced,
    );
  }

  Float32List _delayed(Float32List block) {
    final delay = _rawDelay.length;
    final out = Float32List(block.length)
      ..setRange(0, delay, _rawDelay)
      ..setRange(delay, block.length, block);
    _rawDelay = Float32List.fromList(block.sublist(block.length - delay));
    return out;
  }

  void _trackCleaning(bool voiced, double rawDb, double cleanDb) {
    if (voiced) {
      _recentCleanVoiced.add(cleanDb);
      if (_recentCleanVoiced.length > (1 / _analyzer.blockSec).round()) {
        _recentCleanVoiced.removeAt(0);
      }
    } else {
      // Clean SNR, like the input SNR, describes the current sound only.
      if (_analyzer.quality.phonationSec == 0) _recentCleanVoiced.clear();
      final removed = rawDb - cleanDb;
      final previous = _noiseRemovedDb;
      _noiseRemovedDb = previous == null
          ? removed
          : _reductionSmoothing * previous +
                (1 - _reductionSmoothing) * removed;
    }
  }

  CleaningStats get cleaning {
    final floor = _cleanFloor.floorDb;
    final voiced = _recentCleanVoiced;
    return CleaningStats(
      noiseRemovedDb: _noiseRemovedDb,
      cleanSnrDb: floor == null || voiced.isEmpty
          ? null
          : voiced.reduce((a, b) => a + b) / voiced.length - floor,
    );
  }

  SpectrumView get spectrum => SpectrumView(
    input: logSpectrum(_denoiser.inputDensity, _denoiser.binHz),
    noise: logSpectrum(_denoiser.noiseDensity, _denoiser.binHz),
    clean: logSpectrum(_denoiser.outputDensity, _denoiser.binHz),
  );
}

/// Min/max pairs for drawing [samples] as [count] columns.
List<WaveColumn> waveColumns(Float32List samples, int count) {
  final size = samples.length ~/ count;
  return [
    for (var c = 0; c < count; c++)
      () {
        var lo = 0.0;
        var hi = 0.0;
        for (var i = c * size; i < (c + 1) * size; i++) {
          lo = min(lo, samples[i]);
          hi = max(hi, samples[i]);
        }
        return (min: lo, max: hi);
      }(),
  ];
}

/// Resamples a linear-frequency spectrum onto [SpectrumView.points] log-spaced
/// points, in dB. Each point takes the loudest bin it covers so narrow peaks
/// such as hum stay visible.
List<double> logSpectrum(Float64List density, double binHz) {
  const n = SpectrumView.points;
  final ratio = SpectrumView.maxHz / SpectrumView.minHz;
  double edge(int i) => SpectrumView.minHz * pow(ratio, i / n);
  return [
    for (var i = 0; i < n; i++)
      () {
        final low = (edge(i) / binHz).floor();
        final high = max(low, (edge(i + 1) / binHz).floor() - 1);
        var peak = 0.0;
        for (var k = low; k <= high && k < density.length; k++) {
          peak = max(peak, density[k]);
        }
        return powerDb(peak);
      }(),
  ];
}
