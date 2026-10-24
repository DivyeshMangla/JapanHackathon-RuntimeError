import 'dart:math';
import 'dart:typed_data';

import 'fft.dart';

/// Exponential integral E1(x) for x > 0 (Numerical Recipes `expint`): a
/// power series below 1 and a continued fraction above.
double exponentialIntegral(double x) {
  const euler = 0.5772156649015329;
  const epsilon = 1e-10;
  if (x <= 1) {
    var sum = -log(x) - euler;
    var term = 1.0;
    for (var i = 1; i < 100; i++) {
      term *= -x / i;
      final delta = -term / i;
      sum += delta;
      if (delta.abs() < sum.abs() * epsilon) break;
    }
    return sum;
  }
  var b = x + 1;
  var c = 1 / 1e-30;
  var d = 1 / b;
  var h = d;
  for (var i = 1; i < 100; i++) {
    final a = -i * i.toDouble();
    b += 2;
    d = 1 / (a * d + b);
    c = b + a / c;
    final delta = c * d;
    h *= delta;
    if ((delta - 1).abs() < epsilon) break;
  }
  return h * exp(-x);
}

/// Log-spectral amplitude (log-MMSE) noise reduction, after Ephraim and
/// Malah (1985), with the decision-directed a priori SNR.
///
/// Unlike a gate, it lowers noise underneath the voice: each frequency bin is
/// turned down according to how far it stands above the learned noise
/// spectrum, so voice harmonics pass while the noise between them drops.
/// The noise spectrum is learned only from frames the caller marks as
/// background, so a long held vowel is never learned as noise.
///
/// Display only. Clinical voice measures need the unprocessed signal.
class SpectralDenoiser {
  SpectralDenoiser({required this.sampleRate, this.frameSize = 1024})
    : hop = frameSize ~/ 2,
      _fft = Fft(frameSize),
      _window = Float64List.fromList([
        for (final w in hannWindow(frameSize)) sqrt(w),
      ]),
      _frame = Float64List(frameSize),
      _overlap = Float64List(frameSize),
      _real = Float64List(frameSize),
      _imag = Float64List(frameSize),
      _noise = Float64List(frameSize ~/ 2 + 1),
      _previousClean = Float64List(frameSize ~/ 2 + 1),
      _inputPower = Float64List(frameSize ~/ 2 + 1),
      _outputPower = Float64List(frameSize ~/ 2 + 1);

  /// Smoothing of the decision-directed a priori SNR. Values near 1 suppress
  /// "musical noise", the warbling tones left by plain spectral subtraction.
  static const _decisionDirected = 0.98;

  /// The a priori SNR floor (-25 dB), which also limits musical noise.
  static const _minPrioriSnr = 0.00316;

  /// Deepest cut per bin (-25 dB). Removing noise entirely sounds unnatural
  /// and makes the leftover artefacts more obvious.
  static const gainFloor = 0.056;

  /// Per-frame noise update weight while in background (~0.25 s memory).
  static const _noiseSmoothing = 0.95;

  /// A background bin may raise the noise estimate by at most this factor
  /// per frame, so a door knock is not learned as noise.
  static const _maxNoiseRise = 10.0;

  /// Frames at start-up assumed to be background, to seed the estimate.
  static const _seedSeconds = 0.25;

  static const _displaySmoothing = 0.6;

  final int sampleRate;
  final int frameSize;
  final int hop;
  final Fft _fft;
  final Float64List _window;
  final Float64List _frame;
  final Float64List _overlap;
  final Float64List _real;
  final Float64List _imag;
  final Float64List _noise;
  final Float64List _previousClean;
  final Float64List _inputPower;
  final Float64List _outputPower;
  int _frames = 0;

  int get bins => frameSize ~/ 2 + 1;

  double get binHz => sampleRate / frameSize;

  /// Output lags input by this many samples (one hop of overlap-add).
  int get latencySamples => frameSize - hop;

  /// Squared sqrt-Hann window summed: half the frame.
  double get _windowEnergy => frameSize / 2;

  /// Denoises [input], whose length must be a whole number of hops. Returns
  /// the same number of samples, delayed by [latencySamples].
  Float32List process(Float32List input, {required bool speech}) {
    assert(input.length % hop == 0, 'input must be whole hops');
    final output = Float32List(input.length);
    for (var start = 0; start < input.length; start += hop) {
      _processHop(input, start, output, speech);
    }
    return output;
  }

  void _processHop(
    Float32List input,
    int start,
    Float32List output,
    bool speech,
  ) {
    _frame.setRange(0, frameSize - hop, _frame, hop);
    for (var i = 0; i < hop; i++) {
      _frame[frameSize - hop + i] = input[start + i];
    }
    for (var i = 0; i < frameSize; i++) {
      _real[i] = _frame[i] * _window[i];
      _imag[i] = 0;
    }
    _fft.forward(_real, _imag);

    final seeding = _frames < (_seedSeconds * sampleRate / hop).round();
    for (var k = 0; k < bins; k++) {
      final power = _real[k] * _real[k] + _imag[k] * _imag[k];
      _updateNoise(k, power, seeding: seeding, speech: speech);
      final gain = _gain(k, power);
      _previousClean[k] = gain * gain * power;
      _inputPower[k] = _smooth(_inputPower[k], power);
      _outputPower[k] = _smooth(_outputPower[k], gain * gain * power);
      _real[k] *= gain;
      _imag[k] *= gain;
      if (k > 0 && k < frameSize ~/ 2) {
        _real[frameSize - k] *= gain;
        _imag[frameSize - k] *= gain;
      }
    }

    _fft.inverse(_real, _imag);
    for (var i = 0; i < frameSize; i++) {
      _overlap[i] += _real[i] * _window[i];
    }
    for (var i = 0; i < hop; i++) {
      output[start + i] = _overlap[i];
    }
    _overlap
      ..setRange(0, frameSize - hop, _overlap, hop)
      ..fillRange(frameSize - hop, frameSize, 0);
    _frames++;
  }

  void _updateNoise(
    int k,
    double power, {
    required bool seeding,
    required bool speech,
  }) {
    if (seeding) {
      _noise[k] += (power - _noise[k]) / (_frames + 1);
    } else if (!speech) {
      final capped = _noise[k] <= 0
          ? power
          : min(power, _noise[k] * _maxNoiseRise);
      _noise[k] = _noiseSmoothing * _noise[k] + (1 - _noiseSmoothing) * capped;
    }
  }

  double _gain(int k, double power) {
    final noise = max(_noise[k], 1e-20);
    final posteriori = min(power / noise, 1e6);
    final priori = max(
      _decisionDirected * _previousClean[k] / noise +
          (1 - _decisionDirected) * max(posteriori - 1, 0),
      _minPrioriSnr,
    );
    final ratio = priori / (1 + priori);
    final v = max(ratio * posteriori, 1e-8);
    final gain = v > 50 ? ratio : ratio * exp(0.5 * exponentialIntegral(v));
    return gain.clamp(gainFloor, 1.0);
  }

  double _smooth(double previous, double value) =>
      _displaySmoothing * previous + (1 - _displaySmoothing) * value;

  Float64List _density(Float64List power) => Float64List.fromList([
    for (final p in power) toDensity(p, _windowEnergy, sampleRate),
  ]);

  /// Learned noise spectrum, input spectrum and cleaned spectrum, as power
  /// spectral density per bin of [binHz].
  Float64List get noiseDensity => _density(_noise);
  Float64List get inputDensity => _density(_inputPower);
  Float64List get outputDensity => _density(_outputPower);
}
